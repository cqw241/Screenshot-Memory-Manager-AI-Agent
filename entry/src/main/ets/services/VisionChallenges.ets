export interface VisionChallenge {
  id: string;
  prompt: string;
  expectedAnswer: string;
  imageDataURL: string;
}

const RED_LEFT_BLUE: VisionChallenge = {
  id: 'red-circle-left-blue-square-v1',
  prompt: '观察图片中红色圆形和蓝色方形的位置。如果红圆在蓝方左侧，只返回 RED_LEFT_BLUE；如果蓝方在红圆左侧，只返回 BLUE_LEFT_RED；看不见图片则返回 CANNOT_SEE。不要解释。',
  expectedAnswer: 'RED_LEFT_BLUE',
  imageDataURL: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAA2UlEQVR42u3auw2DMBSFYbhiFfqUWYCGPTJV9kiTBVKmZxhT0CARBfw6Buu/JS+dzwZxjWidc82Vy5qLFwAAAAAAAAAAAAAAAAAAKFWd7wnTcN9u7N8fr4vcHq/46N/n6Af4GX29y5ehm4E/0YszLFX64OPzAsLSKA2WKYfMUO97IH4INZNQ6QykGjzBJNALAQAA4IyAVB2loDOt9xaKHzzNwqDqhzhmCGXrMsuRQ7mqtORpxGvi7nim3dbyvF8ldhlFoi/V8rMHAAAAAAAAAAAAAAAAAAAIqxlEYzyDu+w5QQAAAABJRU5ErkJggg=='
};

const GREEN_ABOVE_BLACK: VisionChallenge = {
  id: 'green-triangle-above-black-square-v1',
  prompt: '观察图片中绿色三角形和黑色方形的位置。如果绿三角在黑方上方，只返回 GREEN_ABOVE_BLACK；如果在下方，只返回 GREEN_BELOW_BLACK；看不见图片则返回 CANNOT_SEE。不要解释。',
  expectedAnswer: 'GREEN_ABOVE_BLACK',
  imageDataURL: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAAwUlEQVR42u3ZyxGAIAxFUcjYC2ubsS7boxpc2ACQRMxwszfjyYuOn9xaS5FLUvACAACAc533FRjwnr2rgRXqWx6/EEig+9p1CkG+vPN4GFihwTGbh0AC4wO2DUGWPDUYGlih2aFahUACinGahCBrn/j1hu1XSD9CZYe9E7C6FWr6yE/e1qe77bpCHq8mcz23TMDvE8NE58z/AQAAAADQ1KE8vpSiP4laKysEAAAAAAAAAAAAAAAAAAAAAAhWfJ1eXQ9aQC5ANpTJmwAAAABJRU5ErkJggg=='
};

export const VISION_CHALLENGES: VisionChallenge[] = [RED_LEFT_BLUE, GREEN_ABOVE_BLACK];

export function chooseChallenge(randomValue: number = Math.random()): VisionChallenge {
  const bounded: number = Math.max(0, Math.min(0.999999, randomValue));
  return VISION_CHALLENGES[Math.floor(bounded * VISION_CHALLENGES.length)];
}
