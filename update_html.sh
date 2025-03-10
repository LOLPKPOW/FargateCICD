#!/bin/bash

# Replace placeholder with the current date/time
sed "s/{{LAST_UPDATED}}/$(date)/g" /usr/local/apache2/htdocs/index.template.html > /usr/local/apache2/htdocs/index.html
