# ActiveStorage ClientSideEncrypted

**WIP: not on Rubygems yet. If you want to use it, point to this git.**

Based upon https://ankane.org/aws-client-side-encryption but enhanced with. Implements Client-Side encryption and total proxying through Rails. So you might loose some performance, as all Storage requests will go through the Rails-stack.

Fortunately, since 6.1 or so, Rails saves the `service_name` onto the Blob, so it is easy to migrate over one by one.

What works:

- [x] uses static string key (32 byte) with ``encryption_key: "xx"`` config.
- [x] uses Aws::S3::EncryptionV2 interface
- [x] supports "direct-upload" via Disk-Service controller. Important: If EncryptedS3 is not the default storage, than you need to patch/hack the ActiveStorage::Blob#direct_upload_url to handle a different service.
- [x] supports linking via Proxy Routing
- [x] Supports "chunked" downloading and range requests (not really - it will download the whole thing and decrypt it in memory - no other way, but still fullfils the API)
- [x] Variants - Needs Rails7 for tracked variants, otherwise not possible via Proxy
- [ ] Preview - not needed until now
- [ ] Mirror - never used
- [ ] Different Encryption Key formats - currently only static encryption key, but Aws-sdk also supports private/public key and more
- [ ] Tests, Different Providers than Aws-S3, should work too, but not tested.

## Installation

```ruby
gem 'active_storage_client_side_encrypted', git: 'https://github.com/pludoni/active_storage_client_side_encrypted.git'
```

## Usage

```yaml
encrypted_amazon:
  service: EncryptedS3  # <---- Important
  access_key_id: <%= Rails.application.secrets.dig(:aws, :access_key_id) %>
  secret_access_key: <%= Rails.application.secrets.dig(:aws, :secret_access_key) %>
  region: <%= Rails.application.secrets.dig(:aws, :region) %>
  bucket: <%= Rails.application.secrets.dig(:aws, :bucket) %>
  # Static Encryption Key: 32 bytes
  encryption_key: <%= Rails.application.secret_key_base[0..31] %>
```

### tell direct upload to use `encrypted_amazon` service

- Unfortunately, the Direct Upload will always use the default service. To pass a different service, you have to patch the `DirectUploadController#direct_upload_url` method, for example using ``?service_name=xxx``.

```ruby
# config/initializers/active_storage_direct_upload_patch.rb
module ASDirectUploadPatch
  def blob_args
    service_name = params[:service_name].presence
    super.merge(service_name: service_name)
  end
end

Rails.application.reloader.to_prepare do
  ActiveStorage::DirectUploadsController.prepend ASDirectUploadPatch
end
```
Then, you can link to the direct upload url like this:

```erb
<%= f.file_field :file, multiple: true, "data-direct-upload-url" => rails_direct_uploads_url(service_name: 'encrypted_amazon') %>
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
