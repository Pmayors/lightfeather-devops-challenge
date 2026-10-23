# I replaced `npm start` (the Vite dev server on port 3000).
# The image has to run the production build so VITE_API_URL and VITE_BASE get written into the files.
# nginx serves that build on port 80.
FROM node:24-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
ARG VITE_API_URL=http://localhost:8080/
ARG VITE_BASE=/
ENV VITE_API_URL=$VITE_API_URL
ENV VITE_BASE=$VITE_BASE
RUN npm run build

FROM nginx:stable-alpine
ARG VITE_BASE=/
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build /tmp/build
RUN set -eu; \
    rm -rf /usr/share/nginx/html/*; \
    if [ "$VITE_BASE" = "/" ]; then \
      cp -a /tmp/build/. /usr/share/nginx/html/; \
    else \
      prefix=$(printf '%s' "$VITE_BASE" | sed 's#^/##; s#/$##'); \
      mkdir -p "/usr/share/nginx/html/${prefix}"; \
      cp -a /tmp/build/. "/usr/share/nginx/html/${prefix}/"; \
    fi; \
    rm -rf /tmp/build
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
