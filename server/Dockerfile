FROM node:20-alpine

WORKDIR /app

# نسخ ملفات الحزم
COPY package*.json ./

# تثبيت الحزم (production فقط)
RUN npm install --omit=dev

# نسخ الكود
COPY src ./src

# المنفذ
EXPOSE 3000

# المستخدم غير الجذر
USER node

# تشغيل
CMD ["node", "src/index.js"]
