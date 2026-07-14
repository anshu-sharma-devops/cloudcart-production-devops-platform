FROM nginx:1.28-alpine

LABEL maintainer="Anshu Sharma"
LABEL project="CloudCart Production DevOps Platform"
LABEL application="cloudcart-placeholder"

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://127.0.0.1/health || exit 1