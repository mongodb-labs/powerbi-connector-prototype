# This Repository is NOT a supported MongoDB product

MongoDB PowerBI Connector Prototype
===================================

This repo contains active development on a custom ODBC connector for PowerBI.

The implementation is currently subject to change at any time. You should not use this connector in production as it is still under development and is in no way supported by MongoDB Inc. 

# Quickstart
1. Install Power BI Desktop
2. Go to File | Options and settings | Options
3. Go the Security tab
4. Under Data Extensions, select Allow any extension to load without warning or validation
5. Restart Power BI Desktop
6. Create a new set of folders that match the following directory path [Documents]\Power BI Desktop\Custom Connectors
7. In the newly created "Custom Connectors" folder, place the *.mez file found in this repo
8. Launch Power BI Desktop and find the connector by going through the 'Get Data' window.
