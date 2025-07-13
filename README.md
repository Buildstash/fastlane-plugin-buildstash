# Fastlane Buildstash Plugin

## Overview
The `fastlane-plugin-buildstash` plugin allows you to upload build artifacts to Buildstash seamlessly as part of your Fastlane workflow. This plugin ensures that your builds are efficiently stored and accessible for further processing.

## Installation
You can install this plugin to your project running:

```sh
fastlane add_plugin buildstash
```

Or, to use a copy of this plugin locally, add it to your `Pluginfile`:

```ruby
gem 'fastlane-plugin-buildstash', path: '/path/to/fastlane-plugin-buildstash'
```

Then run:

```sh
bundle install
```

## Usage
To upload an artifact to Buildstash, use the `buildstash_upload` action in your `Fastfile`:

```ruby
buildstash_upload(
  api_key: 'your_api_key_here',
  structure: 'file',
  primary_file_path: './path/to/file.apk',
  platform: 'android',
  stream: 'default',
  version_component_1_major: 0,
  version_component_2_minor: 0,
  version_component_3_patch: 1,
  version_component_extra: 'rc',
  version_component_meta: '2024.12.01',
  custom_build_number: '12345',
  notes: '<AppChangelog>',
  source: 'ghactions',
  ci_pipeline: ${{ github.workflow }},
  ci_run_id: ${{ github.run_id }},
  ci_run_url: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }},
  vc_host_type: 'git',
  vc_host: 'github',
  vc_repo_name: ${{ github.repository }},
  vc_repo_url: ${{ github.server_url }}/${{ github.repository }},
  vc_branch: ${{ github.ref_name }},
  vc_commit_sha: ${{ github.sha }},
  vc_commit_url: ${{ github.server_url }}/${{ github.repository }}/commit/${{ github.sha }}
)
```

## Parameters
| Parameter      | Description                                                                  | Required |
|--------------|------------------------------------------------------------------------------|----------|
| `api_key`     | The API key for authentication                                               | ✅       |
| `structure`     | 'file' for single file, 'file+expansion' to include Android expansion file   | ✅       |
| `primary_file_path`     | './path/to/file.apk'                                                         | ✅       |
| `platform`     | 'android' or 'ios' (see Buildstash docs for full list)                       | ✅       |
| `stream`     | Exact name of a build stream in your app                                     | ✅       |
| `version_component_1_major`     | Semantic version (major component)                         | ✅       |
| `version_component_2_minor`     | Semantic version (minor component)                         | ✅       |
| `version_component_3_patch`     | Semantic version (patch component)                         | ✅       |
| `version_component_extra`     | Optional pre-release label (beta, rc1, etc)                 | ✖       |
| `version_component_meta`     | Optional release metadata                                                    | ✖       |
| `custom_build_number`     | Optional custom build number in any format                                   | ✅       |
| `notes`     | Changelog or additional notes                                                | ✖️       |
| `source`     | Where build was produced (`ghactions`, `jenkins`, etc) defaults to cli-upload | ✖️       |
| `ci_pipeline`     | CI pipeline name                                                             | ✖️       |
| `ci_run_id`     | CI run ID                                                                    | ✖️       |
| `ci_run_url`     | CI run URL                                                                   | ✖️       |
| `vc_host_type`     | Version control host type (git, svn, hg, perforce, etc)                      | ✖️       |
| `vc_host`     | Version control host (github, gitlab, etc)                                   | ✖️       |
| `vc_repo_name`     | Repository name                                                              | ✖️       |
| `vc_repo_url`     | Repository URL                                                               | ✖️       |
| `vc_branch`     | Branch name (if applicable)                                                  | ✖️       |
| `vc_commit_sha`     | Commit SHA (if applicable)                                                   | ✖️       |
| `vc_commit_url`     | Commit URL                                                                   | ✖️       |


## Example Output
When the upload is successful, you will see:

```sh
[✔] Upload to Buildstash successful!
```

If the file does not exist, an error will be raised:

```sh
[✗] File not found at path: non_existent_file.apk
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