require "active_storage/service/s3_service"

module ActiveStorage
  class Service::EncryptedS3Service < Service::S3Service
    attr_reader :encryption_client

    def initialize(bucket:, upload: {}, **options)
      # https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Encryption.html
      super_options = options.except(:kms_key_id, :encryption_key)
      super(bucket: bucket, upload: upload, **super_options)

      # TODO: different Key Formats? Pub/Private?
      if options[:encryption_key].to_s[/base64:(.*)/]
        options[:encryption_key] = Base64.decode64($1)
      end
      if options[:encryption_key].length > 32
        raise ArgumentError, "Encryption Key must be 32 bytes"
      end
      @encryption_client = Aws::S3::EncryptionV2::Client.new(
        options.merge(
          key_wrap_schema: :aes_gcm,
          content_encryption_schema: :aes_gcm_no_padding,
          security_profile: :v2 # use :v2_and_legacy to allow reading/decrypting objects encrypted by the V1 encryption client
        )
      )
    end

    def upload(key, io, checksum: nil, filename: nil, content_type: nil, disposition: nil, custom_metadata: {}, **)
      instrument :upload, key: key, checksum: checksum do
        begin
          encryption_client.put_object(
            upload_options.merge(
              body: io,
              # Setting content_md5 on client side encrypted objects is deprecated#.
              # content_md5: checksum,
              bucket: bucket.name,
              metadata: custom_metadata,
              key: key
            )
          )
        rescue Aws::S3::Errors::BadDigest
          raise ActiveStorage::IntegrityError
        end
      end
    end

    def download(key, &block)
      if block_given?
        instrument :streaming_download, key: key do
          blob = get_object_blob(key)
          yield blob
        end
      else
        instrument :download, key: key do
          get_object_blob(key)
        end
      end
    end

    def download_chunk(key, range)
      blob = StringIO.new(get_object_blob(key))
      blob.seek(range.begin)
      blob.read(range.size)
    end

    def url_for_direct_upload(key, expires_in:, content_type:, content_length:, checksum:, custom_metadata: {})
      instrument :url, key: key do |payload|
        verified_token_with_expiration = ActiveStorage.verifier.generate(
          {
            key: key,
            content_type: content_type,
            content_length: content_length,
            checksum: checksum,
            service_name: name
          },
          expires_in: expires_in,
          purpose: :blob_token
        )

        generated_url = url_helpers.update_rails_disk_service_url(verified_token_with_expiration, host: current_host, protocol: 'https')

        payload[:url] = generated_url

        generated_url
      end
    end

    def url_for(blob, expires_in:)
      signed_id = ActiveStorage::Blob.signed_id_verifier.generate blob.id, expires_in: expires_in, purpose: :blob_id
      url_helpers.rails_service_blob_proxy_url(signed_id, filename: blob.filename, host: current_host, protocol: 'https')
    end

    private

    def current_host
      (ActiveStorage::Current.url_options || Rails.application.config.action_mailer.default_url_options)[:host]
    end

    def private_url(key, expires_in:, filename:, content_type:, disposition:, **)
      if key.start_with?('variants/')
        raise ArgumentError, "Not Implemented for variants"
      else
        blob = ActiveStorage::Blob.find_by!(key: key, service_name: name)
        url_for(blob, expires_in: expires_in)
      end
    end

    def public_url(key, **)
      private_url(key)
    end

    def get_object_blob(key)
      encryption_client.get_object(
        bucket: bucket.name,
        key: key
      ).body.string.force_encoding(Encoding::BINARY)
    end

    def url_helpers
      @url_helpers ||= Rails.application.routes.url_helpers
    end
  end
end
