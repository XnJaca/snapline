import { Column, Entity, PrimaryColumn } from 'typeorm';

export type CounterDocType = 'ESTIMATE' | 'INVOICE';

// Se avanza con la función next_document_number(), que toma lock de fila.
// Nunca con SERIAL: los números de una empresa no pueden saltar por otra.
@Entity('document_counter')
export class DocumentCounter {
  @PrimaryColumn({ type: 'uuid', name: 'company_id' })
  companyId!: string;

  @PrimaryColumn({ type: 'enum', enum: ['ESTIMATE', 'INVOICE'], enumName: 'counter_doc_type', name: 'doc_type' })
  docType!: CounterDocType;

  @Column({ type: 'bigint', name: 'next_number', default: 1, transformer: {
    to: (v: number) => v,
    from: (v: string) => Number(v),
  } })
  nextNumber!: number;
}
