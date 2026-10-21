import '@fontsource/plus-jakarta-sans/400.css';
import '@fontsource/plus-jakarta-sans/600.css';
import '@fontsource/plus-jakarta-sans/700.css';
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import { LazyMotion, domAnimation } from 'framer-motion';
import App from './App.tsx';
import { AuthProvider } from '@/contexts/AuthContext';
import './index.css';

createRoot(document.getElementById('root')!).render(<StrictMode><LazyMotion features={domAnimation}><BrowserRouter><AuthProvider><App /></AuthProvider></BrowserRouter></LazyMotion></StrictMode>);
