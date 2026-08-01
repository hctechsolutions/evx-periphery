# Use a lightweight Nginx image to serve static files
FROM nginx:alpine

# Define the directory where the documentation is located
ARG DOCS_DIR=docs/book

# Copy the documentation to Nginx's default serving directory
COPY ${DOCS_DIR} /usr/share/nginx/html

RUN echo "#print-button {display: none};" >> /usr/share/nginx/html/book.css

# Expose port 80 to serve the documentation
EXPOSE 80

# Default command to run Nginx
CMD ["nginx", "-g", "daemon off;"]