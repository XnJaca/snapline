import { SetMetadata } from '@nestjs/common';
import { Permission } from '../permissions';

export const REQUIRED_PERMISSION = 'requiredPermission';
export const RequirePermission = (permission: Permission) =>
  SetMetadata(REQUIRED_PERMISSION, permission);
