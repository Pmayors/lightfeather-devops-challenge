// Vite inlines VITE_* at build time. The image build passes the load balancer URL.
const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8080/'

export { API_URL }
export default API_URL