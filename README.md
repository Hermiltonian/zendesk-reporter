# zendesk-reporter
Zendeskチケット情報を取得するツールです。

# 使い方
## APIトークン
同じディレクトリに`token.txt`を以下の内容で作成してください。

```token.txt
email=(あなたのアカウントメールアドレス)
token=(あなたのAPIトークン)
```

## エージェント一覧
同じディレクトリに`users.csv`を以下の内容で作成してください。

```users.csv
id,name
(ZendeskエージェントID),(本ツールで利用する表示名)
(ZendeskエージェントID),(本ツールで利用する表示名)
```

## 実行
その後、以下を実行してください。

```
$ ./make_report.sh
```

resultsディレクトリに結果が出力されます。
