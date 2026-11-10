# Android release 签名

Release keystore 生成在本机 `keys/`（已 gitignore，勿提交）。

```bash
# 已生成示例（本仓库本地）：
# keys/cute-cat-pet-release.keystore
# alias: cutecat
# 密码文件: keys/cute-cat-pet-release.password

source /workspace/xt/env.sh
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/workspace/cute-cat-pet/keys/cute-cat-pet-release.keystore
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=cutecat
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$(cat /workspace/cute-cat-pet/keys/cute-cat-pet-release.password)"

/workspace/xt/bin/Godot_v4.7.2-stable_linux.x86_64 --path /workspace/cute-cat-pet --headless \
  --export-release Android /workspace/cute-cat-pet/build/cute-cat-pet-0.2.10-release.apk
```

请自行妥善保管 keystore 与密码；丢失后无法用同一签名更新已安装包。
