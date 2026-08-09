import { IsArray, IsInt, IsNotEmpty, IsOptional, IsString, IsUUID, Matches, Max, Min } from 'class-validator';

export class PublishProjectDto {
  // Si se omite se deriva del nombre del proyecto. No cambia una vez publicado.
  @IsOptional() @IsString() @Matches(/^[a-z0-9]+(-[a-z0-9]+)*$/, {
    message: 'El slug va en minúsculas, con guiones y sin acentos',
  }) slug?: string;

  @IsString() @IsNotEmpty() title!: string;
  @IsOptional() @IsString() summary?: string;
  @IsUUID() heroAssetId!: string;
  @IsArray() @IsUUID('all', { each: true }) assetIds!: string[];
  @IsOptional() @IsString() city?: string;
  @IsOptional() @IsUUID() testimonialId?: string;
}

export class BeforeAfterDto {
  @IsUUID() beforeAssetId!: string;
  @IsUUID() afterAssetId!: string;
  @IsOptional() @IsString() caption?: string;
}

export class CreateTestimonialDto {
  @IsUUID() customerId!: string;
  @IsUUID() projectId!: string;
  @IsOptional() @IsInt() @Min(1) @Max(5) rating?: number;
  @IsString() @IsNotEmpty() body!: string;
}

export class MarkContentUsedDto {
  @IsOptional() @IsUUID() sourceProjectId?: string;
  @IsString() @IsNotEmpty() platform!: string;
  @IsOptional() @IsString() content?: string;
  @IsArray() @IsUUID('all', { each: true }) assetIds!: string[];
}
