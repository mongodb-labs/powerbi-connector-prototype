// Use this file to write queries to test your data connector
let
    result = MongoDBPBI.Contents("bic-sandbox-biconnector-gnkz6.mongodb.net","movies", "27015")
in
    result