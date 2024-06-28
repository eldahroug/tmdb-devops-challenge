FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm cache clean --force
RUN npm install
RUN npm install eslint --save-dev
RUN npm install eslint-config-react-app --save-dev #--legacy-peer-deps
COPY . .
EXPOSE 3000
CMD [ "npm", "start"]
