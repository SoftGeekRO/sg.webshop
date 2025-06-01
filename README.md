# 🛍️ SoftGeek Online Store

![License](https://img.shields.io/github/license/SoftGeekRO/sg.webShop)
![Python](https://img.shields.io/badge/Python-%3E%3D3.12-blue)
![Django](https://img.shields.io/badge/Django-5.0-green)
![Code Style](https://img.shields.io/badge/code%20style-black-000000)
![Size](https://img.shields.io/github/repo-size/SoftGeekRO/sg.webShop)
![Build](https://img.shields.io/github/actions/workflow/status/SoftGeekRO/sg.webShop/ci.yml?branch=main)
![Issues](https://img.shields.io/github/issues/SoftGeekRO/sg.webShop)
![softgeek.ro](https://img.shields.io/website?url=https://softgeek.ro)
![progeek.ro](https://img.shields.io/website?url=https://progeek.ro)

An advanced e-commerce web application for **SoftGeek**, built
with [Django](https://www.djangoproject.com/), [Webpack](https://webpack.js.org/), [MySQL/MariaDB](https://mariadb.org/),
and modern frontend tools.

---

## 🧱 Stack Overview

| Technology | Purpose                                    |
|------------|--------------------------------------------|
| Django     | Python web framework for backend logic     |
| MariaDB    | Reliable and performant SQL database       |
| Webpack    | Asset bundler for JavaScript/CSS           |
| SCSS       | Professional grade CSS extension language  |
| JavaScript | Interactive frontend                       |
| Nginx      | Reverse proxy and static file serving      |

---

## 🚀 Features

- Product catalog with categories, filters, and search
- Cart and checkout system
- Customer authentication and registration
- Order management dashboard (Admin)
- Multi-language and multi-currency support
- Dynamic frontend assets via Webpack
- Page-level and object caching
- Django admin panel for managing inventory and multistore settings
- REST API support for mobile/third-party apps

---

## 📂 Project Structure

```
/backend
  /core             # Django project settings
  /shop             # E-commerce app logic
  /users            # Custom user auth
  /orders           # Order management
  /api              # REST API
/frontend
  /src              # JavaScript/SCSS entry points
  /dist             # Webpack output (auto-generated)
/static             # Static files served by Nginx
/media              # Uploaded media files
/venv               # Python virtual environment
.env                # Environment config
manage.py           # Django CLI
webpack.config.js   # Webpack config
```

---

## ⚙️ Requirements

- Python >= 3.12
- pip >= 24.x
- Django >= 5.0
- Node.js >= 22.15.x + NPM >= 10.9.x
- webpack >= 5.99
- SASS >= 1.89.0
- MariaDB >= 11.7.2 || MySQL >= 8.0
- Nginx >= 1.24

---

## 🔧 Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/SoftGeekRO/sg.webshop.git
cd sg.webShop
```

### 2. Setup Python Virtual Environment

```bash
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

### 3. Setup Environment

Copy `.env.example` to `.env` and update your environment variables:

```bash
cp .env.example .env
```

### 4. Run Migrations

```bash
python manage.py migrate
```

### 5. Create Superuser

```bash
python manage.py createsuperuser
```

### 6. Start Development Server

```bash
python manage.py runserver
```

### 7. Build Frontend Assets

```bash
cd frontend
npm install
npm run dev
```

---

## 🛠️ Development Path

### 📌 Phase 1: Core Setup

- [ ] Setup Django with modular apps
- [ ] Configure database and models (products, categories, users, orders)
- [ ] Integrate Webpack + asset manifest loading
- [ ] Basic frontend templates using Django
- [ ] Admin configuration and permissions

### 📌 Phase 2: Features & Logic

- [ ] Implement online/offline mode
- [ ] Implement user registration/login
- [ ] Import products from CSV, XLS, XML, feeds
- [ ] Product listing with filters and search
- [ ] Shopping cart and checkout flow
- [ ] Admin dashboard for orders and inventory
- [ ] Multistore and vendor support
- [ ] Email notifications for orders and signups

### 📌 Phase 3: Optimization

- [ ] Enable template and query caching
- [ ] Webpack production builds with asset versioning
- [ ] Add image compression and CDN support (optional)
- [ ] Internationalization and localization (i18n)

### 📌 Phase 4: Testing & Launch

- [ ] Write unit and integration tests
- [ ] Perform SEO audit and optimizations
- [ ] Deploy to VPS with Nginx + Gunicorn
- [ ] Set up log monitoring and performance tracking

---

## 👨‍💻 Contributing

Pull requests are welcome. Please fork the repo and use a feature branch. Ensure
code style and tests pass before submitting:

```bash
black .
flake8
pytest
npm run lint
```

---

## 📄 License

This project is licensed under the **MIT License**.

---

## 🧠 About SoftGeek

**SoftGeek** is a modern tech company focused on smart digital products and
automation.
Visit us at [https://softgeek.ro](https://softgeek.ro)
