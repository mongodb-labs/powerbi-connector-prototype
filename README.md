
# MongoDB Power BI Custom Connector (Prototype)

**IMPORTANT: This Repository is NOT a supported MongoDB product**

This repository contains active development on a custom ODBC connector for Power BI. The implementation is currently subject to change at any time. You should not use this connector in production as it is still under development and is in no way supported by MongoDB Inc. 

# Quickstart

## Prerequisites
1. Install the [MongoDB ODBC Driver 1.3.0](https://github.com/mongodb/mongo-odbc-driver/releases/tag/v1.3.0)

## Install the Connector
1. Create the following directory path: ```[Documents]\Power BI Desktop\Custom Connectors```
2. Download the MongoDB Power BI custom connector ```MongoDBPBI.mez``` and place into the ```Custom Connectors``` folder
1. Launch **Power BI Desktop**
2. Browse to File > Options and settings > Options
3. Browse to Security section
4. Under Data Extensions, select "Allow any extension to load without warning or validation"
5. Relaunch Power BI Desktop

## Use the Connector
1. In Power BI, browse to Get Data > More...
2. Search for **MongoDB BI Connector (Beta)**
3. Click Continue when presented with the warning message
4. Enter your MongoDB BI Connector server, port and database
5. Choose "DirectQuery" mode
6. Click OK to continue

> If this is the first time you are connecting to this data source, you will be prompted to enter your MongoDB username and password. (Example: jeff?source=admin and Pass123). This information can be updated in ```File > Options and settings > Data Source settings```
