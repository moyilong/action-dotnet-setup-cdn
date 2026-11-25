# Install .NET SDK with optional CDN

这是一个可通过 `uses` 调用的 GitHub Composite Action，使用仓库内预置的 `install.sh` 安装一个或多个 .NET SDK，并可选地通过自定义 CDN/feed 下载 SDK 包。

## 文件结构

```text
install-dotnet-action/
├── action.yml
├── install.sh
└── README.md
```

## 用法：仓库内本地 Action

把 `install-dotnet-action/` 放到你的仓库中，然后在 workflow 里这样调用：

```yaml
steps:
  - uses: actions/checkout@v4

  - name: Install Dotnet
    uses: ./install-dotnet-action
    with:
      dotnet-sdk-version: 8.0, 9.0, 11.0.100
      dotnet-cdn: https://s3.moyilong.com/public-lfs/dotnet
      verbose: true

  - name: Check dotnet
    run: dotnet --info
```

## 用法：独立仓库发布后调用

如果你把这个目录内容放到一个独立仓库的根目录，并打 tag，例如 `v1`，其他仓库可以这样使用：

```yaml
steps:
  - name: Install Dotnet
    uses: your-org/install-dotnet-action@v1
    with:
      dotnet-sdk-version: 11.0.100
      dotnet-cdn: https://s3.moyilong.com/public-lfs/dotnet
```

## Inputs

| 名称 | 必填 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `dotnet-sdk-version` | 是 | 无 | 一个或多个版本，使用逗号、空格或换行分隔。完整版本（如 `11.0.100`）精确安装；`11.0` 或 `11` 自动安装该 channel 的最新 SDK。 |
| `dotnet-cdn` | 否 | 空 | 自定义 CDN/feed 地址。非空时会传给 `dotnet-install.sh --azure-feed`；为空时使用官方源。 |
| `install-dir` | 否 | `$HOME/.dotnet` | SDK 安装目录。 |
| `skip-non-versioned-files` | 否 | `true` | 为 `true` 时传入 `--skip-non-versioned-files`。 |
| `verbose` | 否 | `false` | 为 `true` 时传入 `dotnet-install.sh --verbose`，输出更详细的安装日志。 |

## Outputs

| 名称 | 说明 |
| --- | --- |
| `dotnet-root` | 本次安装并写入 `DOTNET_ROOT` 的目录。 |

## 迁移前后的差异

你原来的写法：

```yaml
- name: Install Dotnet
  env:
    DOTNET_CDN: https://s3.moyilong.com/public-lfs/dotnet
    DOTNET_SDK_VERSION: 11.0.100
  run: |
    # ...安装脚本...
```

改成：

```yaml
- name: Install Dotnet
  uses: ./install-dotnet-action
  with:
    dotnet-sdk-version: 11.0.100
    dotnet-cdn: https://s3.moyilong.com/public-lfs/dotnet
```

后续步骤无需额外设置 `PATH` 或 `DOTNET_ROOT`，Action 会写入 `$GITHUB_PATH` 和 `$GITHUB_ENV`。
# action-dotnet-setup-cdn
