import { ApiHideProperty } from '@nestjs/swagger';
import { Column, Entity } from 'typeorm';
import { BaseEntity } from '../../common/entities/base.entity';

export type Locale = 'en' | 'es';

@Entity('app_user')
export class AppUser extends BaseEntity {
  @Column({ type: 'citext', nullable: true })
  email!: string | null;

  @Column({ type: 'text', nullable: true })
  phone!: string | null;

  @ApiHideProperty()
  @Column({ type: 'text', name: 'password_hash', select: false })
  passwordHash!: string;

  @Column({ type: 'text' })
  name!: string;

  @Column({ type: 'text', default: 'en' })
  locale!: Locale;

  @Column({ type: 'timestamptz', name: 'deleted_at', nullable: true })
  deletedAt!: Date | null;
}
