FROM node:25 AS build
WORKDIR /app
ENV TARGET=aarch64-linux
ENV HOME=/
RUN curl https://raw.githubusercontent.com/tristanisham/zvm/master/install.sh | bash
ENV ZVM_INSTALL=$HOME/.zvm/self
ENV PATH=$ZVM_INSTALL:$HOME/.zvm/bin:$PATH
RUN zvm install 0.17.0
RUN npm i -g pnpm@12.8.1
COPY . .
RUN ls -alh
RUN pnpm install --frozen-lockfile
RUN pnpm run build:frontend
RUN pnpm run build:backend -Dtarget=$TARGET

FROM scratch
COPY --from=build /app/zig-out/bin/guessquest-server /guessquest-server
EXPOSE 48377
ENTRYPOINT ["/guessquest-server"]