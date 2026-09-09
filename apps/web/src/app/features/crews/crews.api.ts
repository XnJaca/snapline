import { inject, Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { firstValueFrom } from 'rxjs';
import type { components } from '@snapline/contracts';
import { API_BASE_URL } from '../../core/api/api.config';

export type Member = components['schemas']['MemberDto'];
export type MemberWithInvite = components['schemas']['MemberWithInviteDto'];
export type Crew = components['schemas']['CrewDto'];
export type CrewMember = components['schemas']['CrewMemberDto'];
export type CrewAssignment = components['schemas']['CrewAssignmentDto'];
export type Project = components['schemas']['Project'];

@Injectable({ providedIn: 'root' })
export class CrewsApi {
  private readonly http = inject(HttpClient);
  private readonly base = inject(API_BASE_URL);

  // ---- gente
  createMember(body: unknown): Promise<MemberWithInvite> {
    return firstValueFrom(this.http.post<MemberWithInvite>(`${this.base}/memberships`, body));
  }

  updateMember(id: string, body: unknown): Promise<Member> {
    return firstValueFrom(this.http.patch<Member>(`${this.base}/memberships/${id}`, body));
  }

  /** Emite un código nuevo. Es también el camino de la contraseña olvidada. */
  regenerateInvite(id: string): Promise<MemberWithInvite> {
    return firstValueFrom(this.http.post<MemberWithInvite>(`${this.base}/memberships/${id}/invite`, {}));
  }

  deactivate(id: string): Promise<Member> {
    return firstValueFrom(this.http.post<Member>(`${this.base}/memberships/${id}/deactivate`, {}));
  }

  // ---- cuadrillas
  createCrew(body: unknown): Promise<Crew> {
    return firstValueFrom(this.http.post<Crew>(`${this.base}/crews`, body));
  }

  updateCrew(id: string, body: unknown): Promise<Crew> {
    return firstValueFrom(this.http.patch<Crew>(`${this.base}/crews/${id}`, body));
  }

  addCrewMember(crewId: string, body: unknown): Promise<unknown> {
    return firstValueFrom(this.http.post(`${this.base}/crews/${crewId}/members`, body));
  }

  endCrewMember(crewId: string, memberId: string, toDate: string): Promise<unknown> {
    return firstValueFrom(
      this.http.post(`${this.base}/crews/${crewId}/members/${memberId}/end`, { toDate }),
    );
  }

  // ---- asignación
  assign(projectId: string, body: unknown): Promise<unknown> {
    return firstValueFrom(this.http.post(`${this.base}/projects/${projectId}/assignments`, body));
  }

  /** Cierra la labor de esa cuadrilla en esa obra. La pone una persona. */
  endAssignment(projectId: string, assignmentId: string, toDate: string): Promise<unknown> {
    return firstValueFrom(
      this.http.post(`${this.base}/projects/${projectId}/assignments/${assignmentId}/end`, { toDate }),
    );
  }

  unassign(projectId: string, assignmentId: string): Promise<void> {
    return firstValueFrom(
      this.http.delete<void>(`${this.base}/projects/${projectId}/assignments/${assignmentId}`),
    );
  }
}
