import type { Variants } from 'framer-motion';

export const motionTiming = {
  fast: 0.12,
  normal: 0.2,
  slow: 0.25,
  ease: [0.22, 1, 0.36, 1] as const,
};

export const pageVariants: Variants = {
  initial: { opacity: 0, y: 8 },
  animate: { opacity: 1, y: 0, transition: { duration: motionTiming.normal, ease: motionTiming.ease } },
  exit: { opacity: 0, y: 8, transition: { duration: motionTiming.fast, ease: motionTiming.ease } },
};

export const listVariants: Variants = {
  animate: { transition: { staggerChildren: 0.03 } },
};

export const itemVariants: Variants = {
  initial: { opacity: 0, y: 8 },
  animate: { opacity: 1, y: 0, transition: { duration: motionTiming.normal, ease: motionTiming.ease } },
};

export const rightPanelVariants: Variants = {
  initial: { opacity: 0, x: 16 },
  animate: { opacity: 1, x: 0, transition: { duration: motionTiming.slow, ease: motionTiming.ease } },
};

export const modalVariants: Variants = {
  initial: { opacity: 0, scale: 0.97 },
  animate: { opacity: 1, scale: 1, transition: { duration: motionTiming.normal, ease: motionTiming.ease } },
  exit: { opacity: 0, scale: 0.97, transition: { duration: motionTiming.fast, ease: motionTiming.ease } },
};
