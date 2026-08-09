import { distanceMeters } from './geo';

// Coordenadas del sitio del seed (Baltimore).
const SITE = { lat: 39.290385, lng: -76.612189 };

describe('distanceMeters', () => {
  it('devuelve 0 en el mismo punto', () => {
    expect(distanceMeters(SITE.lat, SITE.lng, SITE.lat, SITE.lng)).toBe(0);
  });

  it('unos metros dentro de la obra caen dentro del radio por defecto', () => {
    expect(distanceMeters(SITE.lat, SITE.lng, 39.2904, -76.6122)).toBeLessThan(150);
  });

  it('40 km se detectan como fuera', () => {
    const d = distanceMeters(SITE.lat, SITE.lng, 39.65, -76.61);
    expect(d).toBeGreaterThan(39_000);
    expect(d).toBeLessThan(41_000);
  });

  it('es simétrica', () => {
    const a = distanceMeters(SITE.lat, SITE.lng, 39.3, -76.6);
    const b = distanceMeters(39.3, -76.6, SITE.lat, SITE.lng);
    expect(a).toBe(b);
  });
});
