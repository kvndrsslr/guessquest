FROM node:25 AS build
WORKDIR /app
ENV TARGET=aarch64-linux
ENV HOME=/
RUN curl https://raw.githubusercontent.com/tristanisham/zvm/master/install.sh | bash
ENV ZVM_INSTALL=$HOME/.zvm/self
ENV PATH=$ZVM_INSTALL:$HOME/.zvm/bin:$PATH
RUN zvm install 0.15.2
COPY . .
RUN ls -alh
RUN npm ci
RUN npm run build:frontend
RUN npm run build:backend -- -Dtarget=$TARGET

FROM scratch
COPY --from=build /app/zig-out/bin/guessquest-server /guessquest-server
EXPOSE 48377
ENTRYPOINT ["/guessquest-server"]