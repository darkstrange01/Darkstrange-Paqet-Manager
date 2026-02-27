<div align="center">

```
    ____  ___    ____  __ _________________  ___    _   ______________
   / __ \/   |  / __ \/ //_/ ___/_  __/ __ \/   |  / | / / ____/ ____/
  / / / / /| | / /_/ / ,<  \__ \ / / / /_/ / /| | /  |/ / / __/ __/
 / /_/ / ___ |/ _, _/ /| |___/ // / / _, _/ ___ |/ /|  / /_/ / /___
/_____/_/  |_/_/ |_/_/ |_/____//_/ /_/ |_/_/  |_/_/ |_/\____/_____/
```

**اسکریپت مدیریت تانل‌های [Paqet](https://github.com/hanselime/paqet) — ساده، سریع، بدون دردسر**

---

[![GitHub release](https://img.shields.io/github/v/release/darkstrange01/Darkstrange-Paqet-Manager?style=flat-square)](https://github.com/darkstrange01/Darkstrange-Paqet-Manager/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](../LICENSE)
[![Powered by Paqet](https://img.shields.io/badge/Powered%20by-Paqet-blue?style=flat-square)](https://github.com/hanselime/paqet)
[![Shell](https://img.shields.io/badge/Shell-Bash-green?style=flat-square)](../darkstrange-paqet.sh)

[🇬🇧 English](../README.md)

</div>

---

## 📋 فهرست مطالب

- [معرفی](#-معرفی)
- [امکانات](#-امکانات)
- [پیش‌نیازها](#-پیش‌نیازها)
- [نصب سریع](#-نصب-سریع)
- [راهنمای استفاده](#-راهنمای-استفاده)
- [مسیرهای پیکربندی](#-مسیرهای-پیکربندی)
- [حمایت مالی](#-حمایت-مالی)

---

## 📖 معرفی

**Darkstrange Paqet Manager** یک اسکریپت Bash ساده و سبک است که مدیریت تانل‌های [Paqet](https://github.com/hanselime/paqet) را آسان می‌کند.

Paqet یک ابزار تانل‌سازی در لایه packet خام است که برای دور زدن محدودیت‌های شبکه طراحی شده. این اسکریپت یک منوی تعاملی روی آن می‌سازد تا نیازی به نوشتن YAML یا کار مستقیم با systemd نداشته باشید.

> **اعتبار:** موتور اصلی تانل، [Paqet](https://github.com/hanselime/paqet) نوشته [@hanselime](https://github.com/hanselime) است. این اسکریپت فقط یک لایه مدیریتی است.

---

## ✨ امکانات

- 🚀 **نصب خودکار** باینری Paqet از GitHub Releases
- 🔄 **آپدیت / دانگرید** به هر نسخه موجود
- 🌍 **حالت سرور** (خارج) و 🇮🇷 **حالت کلاینت** (ایران)
- 📡 پشتیبانی از **TCP**، **UDP** و **TCP/UDP**
- 🔀 **پورت مپینگ** — مثلاً `2020=2021`، `443,8080`
- ⚡ انتخاب **حالت KCP** — `fast`، `fast2`، `fast3`
- ⏰ **مدیریت Cron** — ری‌استارت زمان‌بندی‌شده
- 🔁 **ایمپورت خودکار** کانفیگ‌های موجود در `/etc/paqet/`
- 🛠️ **ویرایش** هر پارامتر بدون نیاز به ساخت مجدد تانل
- 📋 **مشاهده لاگ** سرویس‌ها از داخل منو

---

## 📦 پیش‌نیازها

| پیش‌نیاز              | توضیح                                  |
| --------------------- | -------------------------------------- |
| Linux (Ubuntu 20.04+) | Debian-based توصیه می‌شود              |
| دسترسی root           | الزامی                                 |
| `curl` یا `wget`      | برای دانلود باینری Paqet               |
| `systemd`             | برای مدیریت سرویس‌ها                   |
| `cron`                | برای ری‌استارت زمان‌بندی‌شده (اختیاری) |

---

## 🚀 نصب سریع

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/darkstrange01/Darkstrange-Paqet-Manager/main/darkstrange-paqet.sh)
```

یا با wget:

```bash
bash <(wget -qO- https://raw.githubusercontent.com/darkstrange01/Darkstrange-Paqet-Manager/main/darkstrange-paqet.sh)
```

اسکریپت به صورت خودکار آخرین نسخه Paqet را نصب و منوی تعاملی را باز می‌کند.

---

## 📚 راهنمای استفاده

### راه‌اندازی تانل ایران ↔ خارج

**مرحله ۱ — روی سرور ایران (Client)**

1. اسکریپت را اجرا کنید
2. گزینه `1) Configure a new tunnel` را انتخاب کنید
3. حالت `1) Iran Server (Client)` را بزنید
4. IP لوکال (خودکار تشخیص داده می‌شود)، IP سرور خارج، و پورت تانل را وارد کنید
5. یک کلید ۶۴ کاراکتری تولید می‌شود — **آن را ذخیره کنید**
6. پورت‌هایی که می‌خواهید فوروارد شوند را وارد کنید (مثلاً `443,8080`)
7. پروتکل و حالت KCP را انتخاب کنید

**مرحله ۲ — روی سرور خارج (Server)**

1. اسکریپت را اجرا کنید
2. گزینه `1) Configure a new tunnel` را انتخاب کنید
3. حالت `2) Foreign Server (Server)` را بزنید
4. IP لوکال، همان پورت تانل مرحله قبل
5. کلید تولید شده در مرحله ۱ را وارد کنید

هر دو سرویس به صورت خودکار راه‌اندازی می‌شوند.

---

### فرمت پورت‌ها

```
443           → پورت 443 به 127.0.0.1:443
443,8080      → چند پورت با کاما
2020=2021     → پورت 2020 به لوکال 2021
443,2020=2021 → ترکیبی
```

---

## ⚙️ مسیرهای پیکربندی

| مسیر                                  | توضیح                 |
| ------------------------------------- | --------------------- |
| `/etc/darkstrange-paqet/tunnels.conf` | رجیستری تانل‌ها       |
| `/etc/paqet/<n>.yaml`                 | کانفیگ YAML هر تانل   |
| `/etc/systemd/system/<n>.service`     | سرویس systemd هر تانل |
| `/var/log/darkstrange-paqet.log`      | لاگ فعالیت اسکریپت    |

---

## 💖 حمایت مالی

اگر این پروژه به کارتان آمد، می‌توانید از توسعه آن حمایت کنید:

| شبکه                  | آدرس                                               |
| --------------------- | -------------------------------------------------- |
| **BNB (BEP20 / BSC)** | `0x5955968Cc111f7098ecaD6C50F99D95C637670A5`       |
| **USDT (ERC20)**      | `0x5955968Cc111f7098ecaD6C50F99D95C637670A5`       |
| **TRON (TRX)**        | `TUp1cT2s2XUarchmV2JwFp8QqV9ueHwg89`               |
| **TON**               | `UQA_6LvNdtXRjDY_Ts4OYXmNTrXpRV5ETJHj1KbIt-RrDR9v` |

ممنون از حمایت شما! 💖

---

## 📄 لایسنس

MIT — فایل [LICENSE](../LICENSE)

---

<div align="center">
ساخته شده با ❤️ برای آزادی اینترنت
</div>
