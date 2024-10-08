# Використовуємо офіційний образ PHP з Apache
FROM ubuntu:latest

RUN apt update && apt upgrade -y
ENV DEBIAN_FRONTEND=noninteractive
RUN apt install -y apache2 php php-mysql php-redis php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-zip
RUN apt install -y php-intl 
RUN apt install -y wget unzip 
RUN apt install -y php-pear php-dev 
RUN (echo "no" | sudo pecl install redis) || true
RUN echo "extension=redis.so" > sudo tee /etc/php/$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;')/apache2/conf.d/20-redis.ini

# Копіюємо файли конфігурації Apache
COPY /packer/script/wordpress-for-test.pp.ua.conf /etc/apache2/sites-available/wordpress-for-test.pp.ua.conf
RUN ln -s /etc/apache2/sites-available/wordpress-for-test.pp.ua.conf /etc/apache2/sites-enabled/wordpress-for-test.pp.ua.conf
RUN a2ensite wordpress-for-test.pp.ua.conf

# Робочий каталог для WordPress
WORKDIR /var/www/html/

# Встановлення WordPress
COPY wordpress/. ./
COPY packer/script/install_wordpress.sh ./

RUN wget https://downloads.wordpress.org/plugin/redis-cache.latest-stable.zip
RUN unzip redis-cache.latest-stable.zip -d /var/www/html/wp-content/plugins/
RUN chown -R www-data:www-data /var/www/html \
     && chmod -R 755 /var/www/html \
     && chmod +x /var/www/html/install_wordpress.sh
RUN echo "mysql install started" 
RUN apt install -y mysql-client
RUN echo "mysql install finished"
RUN wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
RUN chmod +x /var/www/html/wp-cli.phar
RUN mv /var/www/html/wp-cli.phar /usr/local/bin/wp
RUN apt install -y sudo
RUN rm /var/www/html/index.html
RUN rm /var/www/html/redis-cache.latest-stable.zip


# Відкриття портів Apache
EXPOSE 80

# Запуск Apache у foreground режимі
CMD ["apache2ctl", "-D", "FOREGROUND"]