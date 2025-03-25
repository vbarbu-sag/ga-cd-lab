import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig(({ mode }) => {
  const isProd = mode === 'production'

  return {
    plugins: [react()],
    base: isProd ? 'https://ga-cd-lab-app.azurewebsites.net/' : '/',
    define: {
      'import.meta.env.API_URL': isProd
        ? JSON.stringify('https://ga-cd-lab-api.azurewebsites.net')
        : JSON.stringify('http://localhost:5000'),
    }
  }
})
