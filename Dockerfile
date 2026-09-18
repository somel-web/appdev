FROM debian:bookworm-slim

ARG PHP_VERSION=8.3
ARG ROOT_PASSWORD=changeme
ENV DEBIAN_FRONTEND=noninteractive

# --- Outils de base + dépôts tiers (Sury pour multi-versions PHP, NodeSource pour Node) ---
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg apt-transport-https lsb-release wget \
        sudo vim nano git unzip cron openssh-server supervisor \
    && curl -sSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /usr/share/keyrings/sury-php.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/sury-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" \
        > /etc/apt/sources.list.d/sury-php.list \
    && curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && rm -rf /var/lib/apt/lists/*

# --- Apache + PHP-FPM (version pilotée par PHP_VERSION, d'autres pourront être ajoutées en parallèle plus tard) ---
RUN apt-get update && apt-get install -y --no-install-recommends \
        apache2 \
        php${PHP_VERSION}-fpm php${PHP_VERSION}-cli php${PHP_VERSION}-common \
        php${PHP_VERSION}-mysql php${PHP_VERSION}-curl php${PHP_VERSION}-gd \
        php${PHP_VERSION}-mbstring php${PHP_VERSION}-xml php${PHP_VERSION}-zip php${PHP_VERSION}-sqlite3 \
    && a2enmod proxy_fcgi setenvif rewrite headers \
    && a2enconf php${PHP_VERSION}-fpm \
    && rm -rf /var/lib/apt/lists/*

# --- Node.js (LTS) + Python (version système Debian) ---
RUN apt-get update && apt-get install -y --no-install-recommends \
        nodejs \
        python3 python3-pip python3-venv \
    && rm -rf /var/lib/apt/lists/*

# --- Composer ---
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# --- SSH : root autorisé, clé publique ET mot de passe ---
RUN mkdir -p /var/run/sshd /root/.ssh \
    && chmod 700 /root/.ssh \
    && echo "root:${ROOT_PASSWORD}" | chpasswd \
    && sed -ri 's/^#?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -ri 's/^#?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && sed -ri 's/^#?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# --- Config Apache : vhost par défaut pointant vers /share/htdocs ---
COPY config/apache/sites-available/000-default.conf /etc/apache2/sites-available/000-default.conf

# --- Supervisord : orchestre apache2, php-fpm et sshd dans le même conteneur ---
COPY config/supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 80 22 3001-3006

CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
