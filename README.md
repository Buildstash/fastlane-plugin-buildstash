# Fastlane Buildstash Plugin

## Overview
The `fastlane-plugin-buildstash` plugin allows you to upload build artifacts to Buildstash seamlessly as part of your Fastlane workflow. This plugin ensures that your builds are efficiently stored and accessible for further processing.

## Installation
You can install this plugin to your project running:

### Preferred installation method

```sh
fastlane add_plugin buildstash
```

### Testing locally

Or, to use a copy of this plugin locally, add it to your `Pluginfile`:

```ruby
gem 'fastlane-plugin-buildstash', path: '/path/to/fastlane-plugin-buildstash'
```

Then run:

```sh
bundle install
```

## Usage
To upload an artifact to Buildstash, use the `buildstash_upload` action in your `Fastfile`.

With base required parameters:

```ruby
buildstash_upload(
  api_key: 'BUILDSTASH_APP_API_KEY',
  primary_file_path: './path/to/file.apk',
  platform: 'android',
  stream: 'default',
  version_component_1_major: 0,
  version_component_2_minor: 0,
  version_component_3_patch: 1
)
```

or with all input parameters:

```ruby
lane :run_buildstash_upload do |options|
  buildstash_upload(
    api_key: options[:api_key],
    structure: 'file',
    primary_file_path: './path/to/file.apk',
    platform: 'android',
    custom_target: 'Galaxy Store',
    stream: 'default',
    version_component_1_major: 0,
    version_component_2_minor: 0,
    version_component_3_patch: 1,
    version_component_extra: 'rc',
    version_component_meta: '2024.12.01',
    custom_build_number: '12345',
    labels: ["to-review", "signed"],
    architectures: ["armv6", "armv7", "armv8", "arm64v8", "armv9"],
    notes: '<AppChangelog>',
    source: 'ghactions',
    ci_pipeline: options[:ci_pipeline],
    ci_run_id: options[:ci_run_id],
    ci_run_url: options[:ci_run_url],
    ci_build_duration: '00:05:00',
    vc_host_type: 'git',
    vc_host: 'github',
    vc_repo_name: options[:vc_repo_name],
    vc_repo_url: options[:vc_repo_url],
    vc_branch: options[:vc_branch],
    vc_commit_sha: options[:vc_commit_sha],
    vc_commit_url: options[:vc_commit_url],
    metadata_artifacts: [
      { path: './build.log', description: 'Xcode build log' },
      { path: './test-results.xml', description: 'Unit test results' }
    ]
  )
end
```

### Uploading metadata artifacts

The `metadata_artifacts` parameter lets you attach supplementary files (logs, test results, crash reports, etc.) to a build. Each entry is a Hash with a `:path` key and an optional `:description`:

```ruby
buildstash_upload(
  api_key: ENV['BUILDSTASH_API_KEY'],
  primary_file_path: './MyApp.ipa',
  platform: 'ios',
  stream: 'nightly',
  version_component_1_major: 2,
  version_component_2_minor: 1,
  version_component_3_patch: 0,
  metadata_artifacts: [
    { path: './build.log', description: 'Build log' },
    { path: './test-results.xml', description: 'Unit test results' },
    { path: './crash-report.txt' }
  ]
)
```

**Limits:**
- Maximum **10** metadata artifacts per upload — if more are provided, only the first 10 are uploaded and a warning is logged for the rest
- Maximum **5 MB** per file — files exceeding this limit are skipped with a warning

## Parameters
| Parameter                   | Description                                                                                                  | Required |
|-----------------------------|--------------------------------------------------------------------------------------------------------------|----------|
| `api_key`                   | The API key for authentication                                                                               | ✅       |
| `structure`                 | 'file' for single file, 'file+expansion' to include Android expansion file. will default to 'file'           | ✖       |
| `primary_file_path`         | './path/to/file.apk'                                                                                         | ✅       |
| `platform`                  | 'android' or 'ios' (see [Buildstash docs for full list](https://docs.buildstash.com/integrations/platforms)) | ✅       |
| `custom_target`             | Custom target for this build — must exactly match a target defined in your Buildstash app                    | ✖️       |
| `stream`                    | Exact name of a build stream in your app                                                                     | ✅       |
| `version_component_1_major` | Semantic version (major component)                                                                           | ✅       |
| `version_component_2_minor` | Semantic version (minor component)                                                                           | ✅       |
| `version_component_3_patch` | Semantic version (patch component)                                                                           | ✅       |
| `version_component_extra`   | Optional pre-release label (beta, rc1, etc)                                                                  | ✖       |
| `version_component_meta`    | Optional release metadata                                                                                    | ✖       |
| `custom_build_number`       | Optional custom build number in any format                                                                   | ✖       |
| `labels`                    | Array of labels to attach to build (will be created if they do not already exist)                            | ✖       |
| `architectures`             | Array of architectures this build supports (must be supported by platform)                                   | ✖       |
| `notes`                     | Changelog or additional notes                                                                                | ✖️       |
| `expansion_file_path`       | Path to the expansion file (only used when `structure` is `'file+expansion'`)                                | ✖️       |
| `metadata_artifacts`        | Array of supplementary files to upload with the build (e.g. logs). See [Metadata artifacts](#uploading-metadata-artifacts) | ✖️ |
| `source`                    | Where build was produced (`ghactions`, `jenkins`, etc) defaults to cli-upload                                | ✖️       |
| `ci_pipeline`               | CI pipeline name                                                                                             | ✖️       |
| `ci_run_id`                 | CI run ID                                                                                                    | ✖️       |
| `ci_run_url`                | CI run URL                                                                                                   | ✖️       |
| `ci_build_duration`         | CI build duration (e.g. `'00:05:00'`)                                                                        | ✖️       |
| `vc_host_type`              | Version control host type (git, svn, hg, perforce, etc)                                                      | ✖️       |
| `vc_host`                   | Version control host (github, gitlab, etc)                                                                   | ✖️       |
| `vc_repo_name`              | Repository name                                                                                              | ✖️       |
| `vc_repo_url`               | Repository URL                                                                                               | ✖️       |
| `vc_branch`                 | Branch name (if applicable)                                                                                  | ✖️       |
| `vc_commit_sha`             | Commit SHA (if applicable)                                                                                   | ✖️       |
| `vc_commit_url`             | Commit URL                                                                                                   | ✖️       |


## Example Output
When the upload is successful, you will see:

```sh
[✔] Upload to Buildstash successful!
```

If the file does not exist, an error will be raised:

```sh
[✗] File not found at path: non_existent_file.apk
```


## Outputs
The buildstash_upload action stores the following outputs in lane_context for in subsequent actions:

| Key | Description |
|-----|-------------|
| `BUILDSTASH_BUILD_ID` | The build ID in Buildstash for the uploaded build |
| `BUILDSTASH_INFO_URL` | Link to view uploaded build within Buildstash workspace |
| `BUILDSTASH_DOWNLOAD_URL` | Link to download the build uploaded to Buildstash (requires login) |

For example, to see these values output:

```ruby
lane :test_plugin do |options|
  buildstash_upload(
    api_key: options[:api_key],
    primary_file_path: "ponderpad.ipa",
    platform: "ios",
    stream: "default",
    version_component_1_major: 1,
    version_component_2_minor: 0,
    version_component_3_patch: 1
  )
  
  # Output to terminal
  UI.message("🔧 Buildstash Build ID: #{lane_context[:BUILDSTASH_BUILD_ID]}")
  UI.message("🔗 Build Info URL: #{lane_context[:BUILDSTASH_INFO_URL]}")
  UI.message("📦 Download URL: #{lane_context[:BUILDSTASH_DOWNLOAD_URL]}")
end
```

## Testing
To run tests:

```sh
bundle exec rspec
```

## Contributing
1. Fork the repository.
2. Create a new branch (`feature/my-feature`).
3. Commit your changes.
4. Push to the branch and create a Merge Request.

Contributions are welcome.

## Support
For issues and feature requests, please contact the internal development team or submit an issue on GitLab.

## Thanks
Credit to [Yann Miecielica](https://github.com/yMiecie) and the team at [Gimbal Cube](https://us.gimbalcube.com/) for contributions to this plugin.