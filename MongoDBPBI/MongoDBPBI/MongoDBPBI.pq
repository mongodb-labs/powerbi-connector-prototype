section MongoDBPBI;

[DataSource.Kind="MongoDBPBI", Publish="MongoDBPBI.Publish"]
shared MongoDBPBI.Contents = (optional message as text) =>
    let
        _message = if (message <> null) then message else "(no message)",
        a = "Hello from MongoDBPBI: " & _message
    in
        a;

// Data Source Kind description
MongoDBPBI = [
    Authentication = [
        // Key = [],
        // UsernamePassword = [],
        // Windows = [],
        Implicit = []
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
MongoDBPBI.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = MongoDBPBI.Icons,
    SourceTypeImage = MongoDBPBI.Icons
];

MongoDBPBI.Icons = [
    Icon16 = { Extension.Contents("MongoDBPBI16.png"), Extension.Contents("MongoDBPBI20.png"), Extension.Contents("MongoDBPBI24.png"), Extension.Contents("MongoDBPBI32.png") },
    Icon32 = { Extension.Contents("MongoDBPBI32.png"), Extension.Contents("MongoDBPBI40.png"), Extension.Contents("MongoDBPBI48.png"), Extension.Contents("MongoDBPBI64.png") }
];
