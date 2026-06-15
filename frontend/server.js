const path = require('path');
const express = require('express');
const axios = require('axios');

const app = express();

const PORT = process.env.PORT || 3000;
const USER_SERVICE_URL = process.env.USER_SERVICE_URL || 'http://localhost:8081';

app.use(express.urlencoded({ extended: true }));
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.post('/send-code', async (req, res) => {
    const email = req.body.email;
    try {
        await axios.post(`${USER_SERVICE_URL}/auth/request-code`, { email });
        res.redirect(`/verify?email=${encodeURIComponent(email)}`);
    } catch (err) {
        console.error('[send-code] falha ao chamar User Service:', err.response?.status, err.response?.data || err.code || err.message);
        const message = err.response?.data?.error || err.response?.data?.message || 'Nao foi possivel enviar o codigo. Tente novamente.';
        res.status(400).send(renderError('Erro ao solicitar codigo', message, '/'));
    }
});

app.get('/verify', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'verify.html'));
});

app.post('/verify-code', async (req, res) => {
    const { email, code } = req.body;
    try {
        const response = await axios.post(`${USER_SERVICE_URL}/auth/verify-code`, { email, code });
        const token = response.data?.token || response.data?.accessToken || response.data;
        res.json({ ok: true, token });
    } catch (err) {
        const message = err.response?.data?.error || err.response?.data?.message || 'Codigo invalido ou expirado.';
        res.status(400).json({ ok: false, message });
    }
});

// ==================== Etapa 4: cadastro de perfil ====================

app.get('/register', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'register.html'));
});

// Recebe name e role do cliente e repassa para o User Service com o JWT.
app.post('/register', async (req, res) => {
    const { name, role } = req.body;
    const auth = req.headers.authorization;
    if (!auth) {
        return res.status(401).json({ ok: false, message: 'Token ausente. Faca login novamente.' });
    }
    try {
        const response = await axios.post(
            `${USER_SERVICE_URL}/users/update-profile`,
            { name, role },
            { headers: { Authorization: auth } }
        );
        res.json({ ok: true, profile: response.data });
    } catch (err) {
        console.error('[register] falha ao chamar User Service:', err.response?.status, err.response?.data || err.code || err.message);
        const message = err.response?.data?.error || err.response?.data?.message || 'Nao foi possivel atualizar o perfil.';
        res.status(err.response?.status || 400).json({ ok: false, message });
    }
});

app.get('/dashboard', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'dashboard.html'));
});

// Proxy para endpoint protegido do User Service.
app.get('/api/protected', async (req, res) => {
    const auth = req.headers.authorization;
    if (!auth) {
        return res.status(401).json({ ok: false, message: 'Token ausente.' });
    }
    try {
        const response = await axios.get(`${USER_SERVICE_URL}/users/test/customer`, {
            headers: { Authorization: auth }
        });
        res.status(response.status).json({ ok: true, data: response.data });
    } catch (err) {
        const message = err.response?.data?.error || err.response?.data?.message || 'Acesso negado ao endpoint protegido.';
        res.status(err.response?.status || 401).json({ ok: false, message });
    }
});

// Proxy para o perfil do usuario logado.
app.get('/api/me', async (req, res) => {
    const auth = req.headers.authorization;
    if (!auth) {
        return res.status(401).json({ ok: false, message: 'Token ausente.' });
    }
    try {
        const response = await axios.get(`${USER_SERVICE_URL}/users/me`, {
            headers: { Authorization: auth }
        });
        res.status(response.status).json(response.data);
    } catch (err) {
        const message = err.response?.data?.error || err.response?.data?.message || 'Nao foi possivel carregar o perfil.';
        res.status(err.response?.status || 401).json({ ok: false, message });
    }
});

function renderError(title, message, backUrl) {
    return `<!DOCTYPE html>
<html lang="pt-br">
<head><meta charset="utf-8"><title>${title}</title></head>
<body style="font-family: sans-serif; max-width: 480px; margin: 60px auto;">
  <h2>${title}</h2>
  <p style="color:#c0392b;">${message}</p>
  <a href="${backUrl}">Voltar</a>
</body>
</html>`;
}

app.listen(PORT, () => {
    console.log(`Frontend rodando em http://localhost:${PORT}`);
    console.log(`User Service esperado em ${USER_SERVICE_URL}`);
});
