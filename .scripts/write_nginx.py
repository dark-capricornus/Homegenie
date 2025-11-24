content = '''server {
    listen       3000;
    server_name  localhost;
    root   /var/www/html;
    index  index.html index.htm;

    # API proxy to backend
    location /api/ {
        proxy_pass http://127.0.0.1:8000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Flutter web routing
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Static assets cache
    location ~* \\.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
}
'''
with open(r'd:\Homegenie\docker\frontend\nginx.conf','w',encoding='utf-8') as f:
    f.write(content)
print('wrote nginx.conf (server-only)')
