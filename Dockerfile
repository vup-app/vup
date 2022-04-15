FROM debian:latest

# Install some Vup dependencies
RUN apt-get update && apt-get install ca-certificates libsodium23 dnsutils ffmpeg atomicparsley -y
# TODO imagemagick openscad inkscape

# Install some Vup dependencies
RUN apt-get install python3 python3-pip -y
RUN pip3 install --upgrade --user yt-dlp
RUN pip3 install --upgrade --user apprise

# Add server binary
ADD bin/main.exe /app/bin/server

# Expose Vup service ports
EXPOSE 4040
EXPOSE 5050

# Start server.
CMD ["/app/bin/server"]