# 服务器预取 Profile

`server-sme.env` 由 `scripts/04_tune_server_profile.sh` 在目标服务器生成，包含
按 stencil 算子选择的预取类别掩码、距离、策略和预算。该文件依赖具体服务器，
已加入 `.gitignore`，不会覆盖其他机器的结果。

生成后使用：

```bash
./scripts/05_validate_tuned_profile.sh
```

`server-sme.env.example` 仅说明文件格式，不代表推荐参数。
