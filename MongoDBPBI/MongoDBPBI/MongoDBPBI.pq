// This connector provides a sample Direct Query enabled connector 
// based on an ODBC driver. It is meant as a template for other 
// ODBC based connectors that require similar functionality.
// 
section MongoDBPBI;

// When set to true, additional trace information will be written out to the User log. 
// This should be set to false before release. Tracing is done through a call to 
// Diagnostics.LogValue(). When EnableTraceOutput is set to false, the call becomes a 
// no-op and simply returns the original value.
EnableTraceOutput = true;

// TODO
// add and handle common options record properties
// add handling for LIMIT/OFFSET vs. TOP 
// add handling for SSL

/****************************
 * ODBC Driver Configuration
 ****************************/

// The name of your ODBC driver.
//
Config_DriverName = "MongoDB ODBC 1.3.0 ANSI Driver";

// If your driver under-reports its SQL conformance level because it does not
// support the full range of CRUD operations, but does support the ANSI SQL required
// to support the SELECT operations performed by Power Query, you can override 
// this value to report a higher conformance level. Please use one of the numeric 
// values below (i.e. 8 for SQL_SC_SQL92_FULL).
// 
// SQL_SC = 
// [
//     SQL_SC_SQL92_ENTRY            = 1,
//     SQL_SC_FIPS127_2_TRANSITIONAL = 2,
//     SQL_SC_SQL92_INTERMEDIATE     = 4,
//     SQL_SC_SQL92_FULL             = 8
// ]
//
// Set to null to determine the value from the driver.
// 
Config_SqlConformance = 8;  // null, 1, 2, 4, 8

// This setting controls row count limits and offsets. If not set correctly, query
// folding capabilities for this connector will be extremely limited. You can use
// the LimitClauseKind constants to match common LIMIT/OFFSET SQL formats. If none
// of the common formats match your desired SQL syntax, set LimitClauseKind to
// LimitClauseKind.None and use the AstVisitor code below (commented out) to
// generate a custom format.
//
// LimitClauseKind values and formats: 
//
// LimitClauseKind.Top (LIMIT only, OFFSET not supported)
// -------------------
// SELECT TOP 100 *
// FROM table
//
// LimitClauseKind.Limit (LIMIT only, OFFSET not supported)
// ---------------------
// SELECT * 
// FROM table
// LIMIT 100
//
// LimitClauseKind.LimitOffset
// ---------------------------
// SELECT *
// FROM table
// LIMIT 100 OFFSET 200
//
// LimitClauseKind.AnsiSql2008
// ---------------------------
// (Limit + Offset)
// SELECT *
//    OFFSET 200 ROWS
//    FETCH FIRST 100 ROWS ONLY
// FROM table
//
Config_LimitClauseKind = LimitClauseKind.LimitOffset; // see above

// Set this option to true if your ODBC supports the standard username/password 
// handling through the UID and PWD connection string parameters. If the user 
// selects UsernamePassword auth, the supplied values will be automatically
// added to the CredentialConnectionString. 
//
// If you wish to set these values yourself, or your driver requires additional
// parameters to be set, please set this option to 'false'
//
Config_DefaultUsernamePasswordHandling = true;  // true, false

// Some drivers have problems will parameter bindings and certain data types. 
// If the driver supports parameter bindings, then set this to true. 
// When set to false, parameter values will be inlined as literals into the generated SQL.
// To enable inlining for a limited number of data types, set this value
// to null and set individual flags through the SqlCapabilities record.
// 
// Set to null to determine the value from the driver. 
//
Config_UseParameterBindings = true;  // true, false, null
 
// Override this setting to force the character escape value. 
// This is typically done when you have set UseParameterBindings to false.
//
// Set to null to determine the value from the driver. 
//
Config_StringLiterateEscapeCharacters  = { "\" }; // ex. { "\" }

// Override this if the driver expects the use of CAST instead of CONVERT.
// By default, the query will be generated using ANSI SQL CONVERT syntax.
//
// Set to false or null to leave default behavior. 
//
Config_UseCastInsteadOfConvert = null; // true, false, null

// Set this to true to enable Direct Query in addition to Import mode.
//
Config_EnableDirectQuery = true;    // true, false

[DataSource.Kind="MongoDBPBI", Publish="MongoDBPBI.Publish"]
shared MongoDBPBI.Contents =  (server as text,  port as text, optional database as text) =>
    let
        //
        // Connection string settings
        //
        ConnectionRecords = if database <> null then  
            [Server = server,
            port = port,
            database = database] else 
            [ Server = server,
            port = port],
        ConnectionString = [
            Driver = Config_DriverName,
            ApplicationIntent = "readonly"
        ] & ConnectionRecords,

        //
        // Handle credentials
        // Credentials are not persisted with the query and are set through a separate 
        // record field - CredentialConnectionString. The base Odbc.DataSource function
        // will handle UsernamePassword authentication automatically, but it is explictly
        // handled here as an example. 
        //
        Credential = Extension.CurrentCredential(),
		CredentialConnectionString =
            if Credential[AuthenticationKind]? = "UsernamePassword" then
                // set connection string parameters used for basic authentication
                [ UID = Credential[Username], PWD = Credential[Password] ]
            else
                error Error.Record("Error", "Unhandled authentication kind: " & Credential[AuthenticationKind]?),
        
        //
        // Configuration options for the call to Odbc.DataSource
        //
        defaultConfig = BuildOdbcConfig(),

        SqlCapabilities = defaultConfig[SqlCapabilities] & [
            // place custom overrides here
            FractionalSecondsScale = 3,
            PrepareStatements = false
        ],

        // Please refer to the ODBC specification for SQLGetInfo properties and values.
        // https://github.com/Microsoft/ODBC-Specification/blob/master/Windows/inc/sqlext.h
        SQLGetInfo = defaultConfig[SQLGetInfo] & [
            // place custom overrides here
            SQL_SQL92_PREDICATES = ODBC[SQL_SP][All],
            SQL_AGGREGATE_FUNCTIONS = ODBC[SQL_AF][All],
      SQL_CONVERT_FUNCTIONS = 0x2 /* CAST */,
      SQL_CONVERT_BIGINT = Flags({BIT,TINYINT,SMALLINT,INTEGER,BIGINT,FLOAT,DOUBLE,REAL,DECIMAL,NUMERIC,CHAR,WCHAR,VARCHAR,WVARCHAR,LONGVARCHAR,WLONGVARCHAR,          TIMESTAMP,INTERVAL_DAY_TIME,INTERVAL_YEAR_MONTH                                    })   
        ],

        // SQLGetTypeInfo can be specified in two ways:
        // 1. A #table() value that returns the same type information as an ODBC
        //    call to SQLGetTypeInfo.
        // 2. A function that accepts a table argument, and returns a table. The 
        //    argument will contain the original results of the ODBC call to SQLGetTypeInfo.
        //    Your function implementation can modify/add to this table.
        //
        // For details of the format of the types table parameter and expected return value,
        // please see: https://docs.microsoft.com/en-us/sql/odbc/reference/syntax/sqlgettypeinfo-function
        //
        // The sample implementation provided here will simply output the original table
        // to the user trace log, without any modification. 
        SQLGetTypeInfo =  #table(
    { "TYPE_NAME",      "DATA_TYPE", "COLUMN_SIZE", "LITERAL_PREF", "LITERAL_SUFFIX", "CREATE_PARAS",           "NULLABLE", "CASE_SENSITIVE", "SEARCHABLE", "UNSIGNED_ATTRIBUTE", "FIXED_PREC_SCALE", "AUTO_UNIQUE_VALUE", "LOCAL_TYPE_NAME", "MINIMUM_SCALE", "MAXIMUM_SCALE", "SQL_DATA_TYPE", "SQL_DATETIME_SUB", "NUM_PREC_RADIX", "INTERNAL_PRECISION"}, {
{"bit",-7,1,null,null,null,null,0,3,null,0,null,"bit(1)",null,null,-7,null,null,null},
{"tinyint",-6,3,null,null,null,null,0,3,0,0,0,"tinyint",null,null,-6,null,10,null},
{"tinyint unsigned",-6,3,null,null,null,null,0,3,1,0,0,"tinyint unsigned",null,null,-6,null,10,null},
{"tinyint auto_increment",-6,3,null,null,null,0,0,3,0,0,1,"tinyint auto_increment",null,null,-6,null,10,null},
{"tinyint unsigned auto_increment",-6,3,null,null,null,0,0,3,1,0,1,"tinyint unsigned auto_increment",null,null,-6,null,10,null},
{"bigint",-5,19,null,null,null,null,0,3,0,0,0,"bigint",null,null,-5,null,10,null},
{"bigint unsigned",-5,20,null,null,null,null,0,3,1,0,0,"bigint unsigned",null,null,-5,null,10,null},
{"bigint auto_increment",-5,19,null,null,null,0,0,3,0,0,1,"bigint auto_increment",null,null,-5,null,10,null},
{"bigint unsigned auto_increment",-5,20,null,null,null,0,0,3,1,0,1,"bigint unsigned auto_increment",null,null,-5,null,10,null},
{"long varbinary",-4,16777215,"0x",null,null,null,0,3,null,0,null,"mediumblob",null,null,-4,null,null,null},
{"blob",-4,65535,"'","'",null,null,0,3,null,0,null,"binary large object (0-65535)",null,null,-4,null,null,null},
{"longblob",-4,2147483647,"'","'",null,null,0,3,null,0,null,"binary large object, use mediumblob instead",null,null,-4,null,null,null},
{"tinyblob",-4,255,"'","'",null,null,0,3,null,0,null,"binary large object (0-255)",null,null,-4,null,null,null},
{"mediumblob",-4,16777215,"'","'",null,null,0,3,null,0,null,"binary large object",null,null,-4,null,null,null},
{"varbinary",-3,255,"'","'","length",null,0,3,null,0,null,"varbinary",null,null,-3,null,null,null},
{"binary",-2,255,"'","'","length",null,0,3,null,0,null,"binary",null,null,-2,null,null,null},
{"long varchar",-1,16777215,"'","'",null,null,0,3,null,0,null,"mediumtext",null,null,-1,null,null,null},
{"text",-1,65535,"'","'",null,null,0,3,null,0,null,"text(0-65535)",null,null,-1,null,null,null},
{"mediumtext",-1,16777215,"'","'",null,null,0,3,null,0,null,"mediumtext",null,null,-1,null,null,null},
{"longtext",-1,2147483647,"'","'",null,null,0,3,null,0,null,"longtext",null,null,-1,null,null,null},
{"tinytext",-1,255,"'","'",null,null,0,3,null,0,null,"tinytext",null,null,-1,null,null,null},
{"char",1,255,"'","'","length",null,0,3,null,0,null,"char",null,null,1,null,null,null},
{"numeric",2,19,null,null,"precision,scale",null,0,3,0,0,0,"numeric",0,19,2,null,10,null},
{"decimal",3,19,null,null,"precision,scale",null,0,3,0,0,0,"decimal",0,19,3,null,10,null},
{"integer",4,10,null,null,null,null,0,3,0,0,0,"integer",null,null,4,null,10,null},
{"integer unsigned",4,10,null,null,null,null,0,3,1,0,0,"integer unsigned",null,null,4,null,10,null},
{"int",4,10,null,null,null,null,0,3,0,0,0,"integer",null,null,4,null,10,null},
{"int unsigned",4,10,null,null,null,null,0,3,1,0,0,"integer unsigned",null,null,4,null,10,null},
{"mediumint",4,7,null,null,null,null,0,3,0,0,0,"Medium integer",null,null,4,null,10,null},
{"mediumint unsigned",4,8,null,null,null,null,0,3,1,0,0,"Medium integer unsigned",null,null,4,null,10,null},
{"integer auto_increment",4,10,null,null,null,0,0,3,0,0,1,"integer auto_increment",null,null,4,null,10,null},
{"integer unsigned auto_increment",4,10,null,null,null,0,0,3,1,0,1,"integer unsigned auto_increment",null,null,4,null,10,null},
{"int auto_increment",4,10,null,null,null,0,0,3,0,0,1,"integer auto_increment",null,null,4,null,10,null},
{"int unsigned auto_increment",4,10,null,null,null,0,0,3,1,0,1,"integer unsigned auto_increment",null,null,4,null,10,null},
{"mediumint auto_increment",4,7,null,null,null,0,0,3,0,0,1,"Medium integer auto_increment",null,null,4,null,10,null},
{"mediumint unsigned auto_increment",4,8,null,null,null,0,0,3,1,0,1,"Medium integer unsigned auto_increment",null,null,4,null,10,null},
{"smallint",5,5,null,null,null,null,0,3,0,0,0,"smallint",null,null,5,null,10,null},
{"smallint unsigned",5,5,null,null,null,null,0,3,1,0,0,"smallint unsigned",null,null,5,null,10,null},
{"smallint auto_increment",5,5,null,null,null,0,0,3,0,0,1,"smallint auto_increment",null,null,5,null,10,null},
{"smallint unsigned auto_increment",5,5,null,null,null,0,0,3,1,0,1,"smallint unsigned auto_increment",null,null,5,null,10,null},
{"double",8,15,null,null,null,null,0,3,0,0,0,"double",0,4,6,null,10,null},
{"double auto_increment",8,15,null,null,null,0,0,3,0,0,1,"double auto_increment",0,4,6,null,10,null},
{"float",7,7,null,null,null,null,0,0,0,0,0,"float",0,2,7,null,10,null},
{"float auto_increment",7,7,null,null,null,0,0,0,0,0,1,"float auto_increment",0,2,7,null,10,null},
{"double",8,15,null,null,null,null,0,3,0,0,0,"double",0,4,8,null,10,null},
{"double auto_increment",8,15,null,null,null,0,0,3,0,0,1,"double auto_increment",0,4,8,null,10,null},
{"date",91,10,"'","'",null,null,0,3,null,0,null,"date",null,null,null,91,null,null},
{"time",92,8,"'","'",null,null,0,3,null,0,null,"time",null,null,null,92,null,null},
{"year",5,4,null,null,null,null,0,3,0,0,0,"year",null,null,5,null,10,null},
{"datetime",93,21,"'","'",null,null,0,3,null,0,null,"datetime",0,0,null,11,null,null},
{"timestamp",93,14,"'","'",null,0,0,3,null,0,null,"timestamp",0,0,null,11,null,null},
{"varchar",12,255,"'","'","length",null,0,3,null,0,null,"varchar",null,null,12,null,null,null}
})

,
                


        // SQLColumns is a function handler that receives the results of an ODBC call
        // to SQLColumns(). The source parameter contains a table with the data type 
        // information. This override is typically used to fix up data type mismatches
        // between calls to SQLGetTypeInfo and SQLColumns. 
        //
        // For details of the format of the source table parameter, please see:
        // https://docs.microsoft.com/en-us/sql/odbc/reference/syntax/sqlcolumns-function
        //
        // The sample implementation provided here will simply output the original table
        // to the user trace log, without any modification. 
       SQLColumns = (catalogName, schemaName, tableName, columnName, source) =>
            if (EnableTraceOutput <> true) then source else
            // the if statement conditions will force the values to evaluated/written to diagnostics
            if (Diagnostics.LogValue("SQLColumns.TableName", tableName) <> "***" and Diagnostics.LogValue("SQLColumns.ColumnName", columnName) <> "***") then
                let
                    // Outputting the entire table might be too large, and result in the value being truncated.
                    // We can output a row at a time instead with Table.TransformRows()
                    rows = Table.TransformRows(source, each Diagnostics.LogValue("SQLColumns", _)),
                    toTable = Table.FromRecords(rows)
                in
                    Value.ReplaceType(toTable, Value.Type(source))
            else
                source,

        OdbcDatasource = Odbc.DataSource(ConnectionString, [
            // A logical (true/false) that sets whether to view the tables grouped by their schema names
            HierarchicalNavigation = true, 
            // Prevents execution of native SQL statements. Extensions should set this to true.
            HideNativeQuery = true,
            // Allows upconversion of numeric types
            SoftNumbers = false,
            // Allow upconversion / resizing of numeric and string types
            TolerateConcatOverflow = true,
            // Enables connection pooling via the system ODBC manager
            ClientConnectionPooling = true,

            // These values should be set by previous steps
            CredentialConnectionString = CredentialConnectionString,
            SqlCapabilities = SqlCapabilities,
            SQLColumns = SQLColumns,
            SQLGetInfo = SQLGetInfo,
            SQLGetTypeInfo = SQLGetTypeInfo
        ])
    in
        OdbcDatasource;  

// Data Source Kind description
MongoDBPBI = [
    // Set the TestConnection handler to enable gateway support.
    // The TestConnection handler will invoke your data source function to 
    // validate the credentials the user has provider. Ideally, this is not 
    // an expensive operation to perform. By default, the dataSourcePath value 
    // will be a json string containing the required parameters of your data  
    // source function. These should be parsed and parsed as individual parameters
    // to the specified data source function.
TestConnection = (dataSourcePath) => 
        let
            json = Json.Document(dataSourcePath),
            server = json[server],
            port = json[port],
            database = json[database] // name of function parameter
        in
            { "MongoDBPBI.Content", server, port, database },
    // Set supported types of authentication
    Authentication = [
        UsernamePassword = []
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
MongoDBPBI.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://docs.mongodb.com/bi-connector/current/",

    SupportsDirectQuery = Config_EnableDirectQuery,

    SourceImage = MongoDBPBI.Icons,
    SourceTypeImage = MongoDBPBI.Icons
];

MongoDBPBI.Icons = [
    Icon16 = { Extension.Contents("MongoDBPBI16.png"), Extension.Contents("MongoDBPBI20.png"), Extension.Contents("MongoDBPBI24.png"), Extension.Contents("MongoDBPBI32.png") },
    Icon32 = { Extension.Contents("MongoDBPBI32.png"), Extension.Contents("MongoDBPBI40.png"), Extension.Contents("MongoDBPBI48.png"), Extension.Contents("MongoDBPBI64.png") }
];

// build settings based on configuration variables
BuildOdbcConfig = () as record =>
    let        
        defaultConfig = [
            SqlCapabilities = [],
            SQLGetFunctions = [],
            SQLGetInfo = []
        ],

        withParams =
            if (Config_UseParameterBindings = false) then
                let 
                    caps = defaultConfig[SqlCapabilities] & [ 
                        SqlCapabilities = [
                            SupportsNumericLiterals = true,
                            SupportsStringLiterals = true,                
                            SupportsOdbcDateLiterals = true,
                            SupportsOdbcTimeLiterals = true,
                            SupportsOdbcTimestampLiterals = true
                        ]
                    ],
                    funcs = defaultConfig[SQLGetFunctions] & [
                        SQLGetFunctions = [
                            SQL_API_SQLBINDPARAMETER = false
                        ]
                    ]
                in
                    defaultConfig & caps & funcs
            else
                defaultConfig,
                
        withEscape = 
            if (Config_StringLiterateEscapeCharacters <> null) then 
                let
                    caps = withParams[SqlCapabilities] & [ 
                        SqlCapabilities = [
                            StringLiteralEscapeCharacters = Config_StringLiterateEscapeCharacters
                        ]
                    ]
                in
                    withParams & caps
            else
                withParams,

        withLimitClauseKind = 
            let
                caps = withEscape[SqlCapabilities] & [ 
                    SqlCapabilities = [
                        LimitClauseKind = Config_LimitClauseKind
                    ]
                ]
            in
                withEscape & caps,

withCastOrConvert = 
            if (Config_UseCastInsteadOfConvert <> null) then
                let
                    value =
                        if (Config_UseCastInsteadOfConvert = true) then 
                            ODBC[SQL_FN_CVT][SQL_FN_CVT_CAST]
                        else
                            ODBC[SQL_FN_CVT][SQL_FN_CVT_CONVERT],
                    caps = withLimitClauseKind[SQLGetInfo] & [ 
                        SQLGetInfo = [
                            SQL_CONVERT_FUNCTIONS = value
                        ]
                    ]
                in
                    withLimitClauseKind & caps
            else
                withLimitClauseKind,

        withSqlConformance =
            if (Config_SqlConformance <> null) then
                let
                    caps = withCastOrConvert[SQLGetInfo] & [
                        SQLGetInfo = [
                            SQL_SQL_CONFORMANCE = Config_SqlConformance
                        ]
                    ]
                in
                    withCastOrConvert & caps
            else
                withCastOrConvert
    in
        withSqlConformance;

// 
// Load common library functions
// 
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

// Diagnostics module contains multiple functions. We can take the ones we need.
Diagnostics = Extension.LoadFunction("Diagnostics.pqm");
Diagnostics.LogValue = if (EnableTraceOutput) then Diagnostics[LogValue] else (prefix, value) => value;

// OdbcConstants contains numeric constants from the ODBC header files, and a 
// helper function to create bitfield values.
ODBC = Extension.LoadFunction("OdbcConstants.pqm");
Flags = (flags as list) => 
    let
        Loop = List.Generate(()=> [i = 0, Combined = 0],
                                each [i] < List.Count(flags),
                                each [i = [i]+1, Combined = Number.BitwiseOr([Combined], flags{i})],
                                each [Combined]),
        Result = List.Last(Loop, 0)
    in
        Result;

CHAR = 0x00000001;
NUMERIC = 0x00000002;
DECIMAL = 0x00000004;
INTEGER = 0x00000008;
SMALLINT = 0x00000010;
FLOAT = 0x00000020;
REAL = 0x00000040;
DOUBLE = 0x00000080;
VARCHAR = 0x00000100;
LONGVARCHAR = 0x00000200;
BINARY = 0x00000400;
VARBINARY = 0x00000800;
BIT = 0x00001000;
TINYINT = 0x00002000;
BIGINT = 0x00004000;
DATE = 0x00008000;
TIME = 0x00010000;
TIMESTAMP = 0x00020000;
LONGVARBINARY = 0x00040000;
INTERVAL_YEAR_MONTH = 0x00080000;
INTERVAL_DAY_TIME = 0x00100000;
WCHAR = 0x00200000;
WLONGVARCHAR = 0x00400000;
WVARCHAR = 0x00800000;
GUID = 0x01000000;
