import { inject, Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { firstValueFrom } from 'rxjs';
import type { components } from '@snapline/contracts';
import { API_BASE_URL } from '../../core/api/api.config';

export type Customer = components['schemas']['Customer'];
export type Site = components['schemas']['Site'];
export type Project = components['schemas']['Project'];

@Injectable({ providedIn: 'root' })
export class CustomersApi {
  private readonly http = inject(HttpClient);
  private readonly base = inject(API_BASE_URL);

  get(id: string): Promise<Customer> {
    return firstValueFrom(this.http.get<Customer>(`${this.base}/customers/${id}`));
  }

  sites(id: string): Promise<Site[]> {
    return firstValueFrom(this.http.get<Site[]>(`${this.base}/customers/${id}/sites`));
  }

  create(body: unknown): Promise<Customer> {
    return firstValueFrom(this.http.post<Customer>(`${this.base}/customers`, body));
  }

  update(id: string, body: unknown): Promise<Customer> {
    return firstValueFrom(this.http.patch<Customer>(`${this.base}/customers/${id}`, body));
  }

  remove(id: string): Promise<void> {
    return firstValueFrom(this.http.delete<void>(`${this.base}/customers/${id}`));
  }

  addSite(customerId: string, body: unknown): Promise<Site> {
    return firstValueFrom(this.http.post<Site>(`${this.base}/customers/${customerId}/sites`, body));
  }

  updateSite(customerId: string, siteId: string, body: unknown): Promise<Site> {
    return firstValueFrom(
      this.http.patch<Site>(`${this.base}/customers/${customerId}/sites/${siteId}`, body),
    );
  }
}
