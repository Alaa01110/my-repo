#!/data/data/com.termux/files/usr/bin/bash

# إعداد هوية Git
git config --global user.email "ngo0m0900@gmail.com"
git config --global user.name "Alaa01110"

# إنشاء README لو مش موجود
if [ ! -f README.md ]; then
  echo "# My First Repo" > README.md
fi

# إضافة و commit
git add README.md
git commit -m "Initial commit" || echo "⚠️ Commit موجود قبل كده"

# تغيير اسم الفرع إلى main
git branch -M main

# دفع إلى GitHub
git push -u origin main
