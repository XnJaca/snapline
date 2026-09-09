import { inject, Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { firstValueFrom } from 'rxjs';
import type { components } from '@snapline/contracts';
import { API_BASE_URL } from '../../core/api/api.config';

export type Project = components['schemas']['Project'];
export type ProjectStatus = Project['status'];

@Injectable({ providedIn: 'root' })
export class ProjectsApi {
  private readonly http = inject(HttpClient);
  private readonly base = inject(API_BASE_URL);

  get(id: string): Promise<Project> {
    return firstValueFrom(this.http.get<Project>(`${this.base}/projects/${id}`));
  }

  create(body: unknown): Promise<Project> {
    return firstValueFrom(this.http.post<Project>(`${this.base}/projects`, body));
  }

  update(id: string, body: unknown): Promise<Project> {
    return firstValueFrom(this.http.patch<Project>(`${this.base}/projects/${id}`, body));
  }
}
