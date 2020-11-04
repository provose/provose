FROM jekyll/builder
USER root
RUN apk add findutils
ADD Gemfile Gemfile.lock /srv/jekyll/
WORKDIR /srv/jekyll
RUN chmod 777 Gemfile.lock && bundle install; exit 0
USER jekyll
EXPOSE 4000