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

## チケット状態レポート取得

```
$ ./make_report.sh
```

results/reportsディレクトリに結果が出力されます。

集計対象から除外したいチケットがある場合、引数にチケットidを指定します。
`make_report.sh [id ...]`

```
$ ./make_report.sh 1021 1030
```

## リクエスターレポート取得

```
$ ./requests.sh html|csv|domain
```

|引数|説明|
|---|---|
|html|HTMLファイルを出力し、表形式で問い合わせを一覧化します|
|csv|問い合わせ一覧をcsvで出力します|
|domain|メールによる問い合わせのリクエスタメールドメインをjson形式で出力します|

results/requestsディレクトリに結果が出力されます。
