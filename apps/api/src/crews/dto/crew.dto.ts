import { IsDateString, IsNotEmpty, IsOptional, IsString, IsUUID } from 'class-validator';

export class CreateCrewDto {
  @IsOptional() @IsUUID() id?: string;
  @IsString() @IsNotEmpty() name!: string;
  @IsOptional() @IsUUID() foremanMembershipId?: string;
  @IsOptional() @IsString() color?: string;
}

export class UpdateCrewDto {
  @IsOptional() @IsString() @IsNotEmpty() name?: string;
  @IsOptional() @IsUUID() foremanMembershipId?: string;
  @IsOptional() @IsString() color?: string;
}

export class AddCrewMemberDto {
  @IsUUID() membershipId!: string;
  @IsDateString() fromDate!: string;
  @IsOptional() @IsDateString() toDate?: string;
}
