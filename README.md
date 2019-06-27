# zendesk-reporter
Zendeskチケット情報を取得するツールです。

# 使い方
同じディレクトリに`token.txt`を以下の内容で作成してください。

```token.txt
email=(あなたのアカウントメールアドレス)
token=(あなたのAPIトークン)
```

その後、以下を実行してください。

```
$ ./make_report.sh
```

resultsディレクトリに結果が出力されます。
