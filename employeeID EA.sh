#!/bin/bash
# ----------------------------------------------------------------------
# Script Name:    employeeID EA.sh
# Description:    Pulls the employee ID from BambooHR then adds it as an Extension Attribute in Jamf Pro.
# Author:         @mtbhuskies
# Created on:     10/08/2024
# Version:        1.0
# ----------------------------------------------------------------------
# Usage:          Include this script in a Jamf Pro Extension Attribute with "Data Type" set to String.
# Example:        N/A
# ----------------------------------------------------------------------
# Environment:    Jamf Pro - Extension Attribute, BambooHR API
# Dependencies:   Requires a BambooHR API key along with read access to the Jamf Pro API. Requires curl, xmllint, and awk.
# ----------------------------------------------------------------------
# Revision History:
#   Date          Author          Description
#   10/08/24      @mtbhuskies     Initial release
# ----------------------------------------------------------------------

#domain
domain="domain"

# Bamboo API
bamboohrAPIKey="apiKey"

# Set variables for Jamf Pro API access
jamfURL="https://$domain.jamfcloud.com"
apiUser="apiUser"
apiPass="apiKey"

# Encode the Jamf Pro username and password in Base64
basicAuth=$(echo -n "${apiUser}:${apiPass}" | base64)

# Get the Bearer token using Basic Auth for Jamf Pro
bToken=$(curl -sk -X POST "${jamfURL}/api/v1/auth/token" \
-H "accept: application/json" \
-H "Authorization: Basic ${basicAuth}" | awk '/token/{print $3}' | tr -d '"'',')

# Get the serial number of the computer from system_profiler
serialNumber=$(system_profiler SPHardwareDataType | awk '/Serial Number/ { print $4 }')
echo "Serial number is $serialNumber"

# Query Jamf Pro API for computer information using the serial number
computerInfo=$(curl -sk -X GET "${jamfURL}/JSSResource/computers/serialnumber/$serialNumber" \
-H "Authorization: Bearer ${bToken}" \
-H "Accept: application/json")

# Extract email from the location section of the computer info using sed
email=$(echo "$computerInfo" | sed -n 's/.*"email_address":"\([^"]*\)".*/\1/p')
echo "Email address is $email"

# Query BambooHR API to get the employee directory in XML format
employeeInfo=$(curl -s -u "${bamboohrAPIKey}:x" \
"https://api.bamboohr.com/api/gateway.php/${domain}/v1/employees/directory" \
-H "Accept: application/xml")

# Save the employee info to a temp XML file
echo "$employeeInfo" > /tmp/employee.xml

# Use xmllint to find the employee ID based on the email
employeeID=$(xmllint --xpath "//employee[field[@id='workEmail' and text()='$email']]/@id" /tmp/employee.xml 2>/dev/null | sed 's/[^0-9]*//g')

# Remove the temporary file
rm -f /tmp/employee.xml

if [ -z "$employeeID" ]; then
  echo "Employee ID not found for $email"
else
  echo "Employee ID for $email is $employeeID"
fi

# Output Employee ID for the extension attribute
echo "<result>$employeeID</result>"