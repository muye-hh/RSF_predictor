FROM rocker/shiny:4.2.3
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev libssl-dev build-essential \
    && rm -rf /var/lib/apt/lists/*
RUN install2.r --error --skipinstalled shiny survival ranger
COPY . /srv/shiny-server/RSFpredictor/
RUN chmod -R 755 /srv/shiny-server/RSFpredictor/
EXPOSE 3838
CMD ["R", "-e", "shiny::runApp('/srv/shiny-server/RSFpredictor/app.R', port=3838, host='0.0.0.0')"]
