FROM httpd:latest

# Copy the HTML template and script into the container
COPY index.template.html /usr/local/apache2/htdocs/index.template.html
COPY update_html.sh /usr/local/apache2/htdocs/update_html.sh

# Run the script to generate index.html with the current timestamp
RUN chmod +x /usr/local/apache2/htdocs/update_html.sh && \
    /usr/local/apache2/htdocs/update_html.sh

EXPOSE 80
