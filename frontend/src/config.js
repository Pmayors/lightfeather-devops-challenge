// I read VITE_API_URL so the built page calls the load balancer.
// If it is missing, npm start on my machine still uses localhost.
const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8080/'

export { API_URL }
export default API_URL