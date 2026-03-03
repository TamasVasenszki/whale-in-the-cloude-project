FROM node:24-alpine3.22

WORKDIR /app

# only dependency files first (cache)
COPY package*.json ./

RUN npm ci --omit=dev

# after the source
COPY . .

EXPOSE 3000

CMD ["npm", "start"]
