#!/bin/sh
# Remove downloaded files older than 1 hour (disk safety)
find /opt/anrsaver/downloads -type f -mmin +60 -delete
