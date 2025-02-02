FROM alpine
MAINTAINER Steven Cacner <cacman14@gmail.com>

# Install nginx
RUN version=$(egrep -o '^[0-9]+\.[0-9]+' /etc/alpine-release) && \
    apk --no-cache --no-progress upgrade && \
    apk --no-cache --no-progress add apache2-utils bash curl openssl shadow \
                tini tzdata && \
    addgroup -S nginx && \
    adduser -S -D -H -h /var/cache/nginx -s /sbin/nologin -G nginx \
                -g 'Nginx User' nginx && \
    curl -LSs https://nginx.org/keys/nginx_signing.rsa.pub \
                -o /etc/apk/keys/nginx_signing.rsa.pub && \
    echo "https://nginx.org/packages/mainline/alpine/v${version}/main" \
                >>/etc/apk/repositories && \
    apk add --no-cache --no-progress nginx && \
    sed -i 's/#gzip/gzip/' /etc/nginx/nginx.conf && \
    sed -i "/http_x_forwarded_for\"';/s/';/ '/" /etc/nginx/nginx.conf && \
    sed -i "/http_x_forwarded_for/a \
\ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ '\$request_time \$upstream_response_time';" \
                /etc/nginx/nginx.conf && \
    echo -e "\n\nstream {\n    include /etc/nginx/conf.d/*.stream;\n}" \
                >>/etc/nginx/nginx.conf && \
    [ -d /srv/www ] || mkdir -p /srv/www && \
    { mv /usr/share/nginx/html/index.html /srv/www/ || :; } && \
    apk add --no-cache --no-progress --virtual .gettext gettext && \
    mv /usr/bin/envsubst /usr/local/bin/ && \
    runDeps="$(scanelf --needed --nobanner /usr/local/bin/envsubst | \
                awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' | \
                sort -u | xargs -r apk info --installed | sort -u)" && \
    apk del --no-cache --no-progress .gettext && \
    apk add --no-cache --no-progress $runDeps && \
    rm -rf /tmp/* && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log
# Forward request and error logs to docker log collector

COPY default.conf /etc/nginx/conf.d/
COPY nginx.sh /usr/bin/

VOLUME ["/srv/www", "/etc/nginx"]

EXPOSE 80 443

HEALTHCHECK --interval=60s --timeout=15s --start-period=120s \
             CMD curl -Lk 'https://localhost/index.html'

ENTRYPOINT ["/sbin/tini", "--", "/usr/bin/nginx.sh"]
