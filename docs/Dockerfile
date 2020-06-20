FROM jekyll/builder
USER root
ADD Gemfile Gemfile.lock /srv/jekyll/
WORKDIR /srv/jekyll
RUN chmod 777 Gemfile.lock && bundle install; exit 0
EXPOSE 4000