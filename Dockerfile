##########################################################################
#### BUILD CONTAINER
##########################################################################
FROM ruby:2.7.3-slim AS builder

RUN apt-get update && \
  apt-get install -qq -y --no-install-recommends \
  build-essential ca-certificates git curl wget gnupg pkg-config libpq-dev libxml2-dev libxslt-dev shared-mime-info

ADD https://dl.yarnpkg.com/debian/pubkey.gpg /tmp/yarn-pubkey.gpg
RUN apt-key add /tmp/yarn-pubkey.gpg && rm /tmp/yarn-pubkey.gpg
RUN echo 'deb http://dl.yarnpkg.com/debian/ stable main' > /etc/apt/sources.list.d/yarn.list
RUN apt-get update && \
  apt-get install -qq -y --no-install-recommends \
  nodejs yarn

# Set environment variables
ENV NODE_ENV=production
ENV RAILS_ENV=production
ENV SECRET_KEY_BASE=foo
ENV RAILS_SERVE_STATIC_FILES=true
ENV BUNDLE_WITHOUT=development:test
ENV BUNDLE_DEPLOYMENT=true

# Configure the main working directory. This is the base
# directory used in any further RUN, COPY, and ENTRYPOINT
# commands.
WORKDIR /app

# Install gems
ADD Gemfile* ./

RUN gem install bundler:2.1.4
RUN bundle config set jobs `expr $(cat /proc/cpuinfo | grep -c 'cpu cores') - 1`
RUN bundle config build.nokogiri --use-system-libraries
RUN bundle install \
  && find vendor/bundle -name "*.c" -delete \
  && find vendor/bundle -name "*.o" -delete \
  && find vendor/bundle -name "*.gem" -delete

# RUN du -h -c -d 4 .

# Install yarn packages
COPY package.json yarn.lock /app/
RUN yarn install

# Add the Rails app
ADD . /app

# RUN du -h -c -d 4 .

# Precompile assets
RUN bundle exec rake assets:precompile

# Remove folders not needed in resulting image
RUN rm -rf spec node_modules vendor/assets lib/assets tmp/cache

# RUN du -h -c -d 4 .

##########################################################################
#### RUNTIME CONTAINER
##########################################################################
FROM ruby:2.7.3-slim

# Install dependencies to build gems
RUN apt-get update && \
  apt-get install -qq -y --no-install-recommends \
  ca-certificates git curl wget libpq5 libxml2 libxslt1.1 nodejs shared-mime-info && \
  rm -rf /var/lib/apt/lists/*

# Add user
RUN addgroup --gid 1000 --system app && \
  adduser -uid 1000 --system --ingroup app --home /app --shell /bin/bash app
USER app

# Copy app with gems from former build stage
COPY --from=builder --chown=app:app /app /app

# Configure the main working directory. This is the base
# directory used in any further RUN, COPY, and ENTRYPOINT
# commands.
WORKDIR /app

# Set environment variables
ENV RAILS_ENV=production
ENV RAILS_SERVE_STATIC_FILES=true
ENV RAILS_LOG_TO_STDOUT=true
ENV BUNDLE_WITHOUT=development:test
ENV BUNDLE_DEPLOYMENT=true
ENV PORT=3000

# Install latest bundler
RUN gem install bundler:2.1.4
RUN bundle install

EXPOSE 3000

CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
