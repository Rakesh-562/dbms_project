import { useState, useMemo } from 'react';
import { useApi } from '../hooks';
import { getBranches, createBankBranch, updateBankBranch } from '../api';
import { PageHeader, Card, DataTable, Badge, Spinner, ErrorBox, Modal, FormField, Input, Select, Btn } from '../components/UI';
import { Search } from 'lucide-react';

const columns = (onEdit) => [
  { key: 'branch_id',        label: 'ID' },
  { key: 'branch_name',      label: 'Name' },
  { key: 'ifsc_code',        label: 'IFSC' },
  { key: 'city',             label: 'City' },
  { key: 'state',            label: 'State' },
  { key: 'phone',            label: 'Phone' },
  { key: 'established_date', label: 'Established', render: (r) => r.established_date?.slice(0, 10) },
  { key: 'status',           label: 'Status', render: (r) => <Badge variant={r.status === 'active' ? 'green' : 'red'}>{r.status}</Badge> },
  { key: '_edit', label: '', render: (r) => <Btn variant="secondary" onClick={() => onEdit(r)}>Edit</Btn> },
];

const empty = { branch_name: '', ifsc_code: '', address: '', city: '', state: '', pincode: '', phone: '', email: '', established_date: '' };

export default function BranchesPage() {
  const { data, loading, error, refetch } = useApi(getBranches);
  const [modal, setModal] = useState(null);
  const [form, setForm] = useState(empty);
  const [saving, setSaving] = useState(false);
  const [formError, setFormError] = useState(null);
  const [search, setSearch] = useState('');

  const filtered = useMemo(() => {
    if (!data || !search.trim()) return data || [];
    const q = search.toLowerCase();
    return data.filter(r => [r.branch_name, r.ifsc_code, r.city, r.state, r.phone, r.status].some(v => v && String(v).toLowerCase().includes(q)));
  }, [data, search]);

  const openAdd = () => { setForm(empty); setFormError(null); setModal('add'); };
  const openEdit = (r) => { setForm({ ...r, established_date: r.established_date?.slice(0, 10) || '' }); setFormError(null); setModal(r); };
  const close = () => { setModal(null); setFormError(null); };
  const set = (k, v) => setForm(f => ({ ...f, [k]: v }));

  const save = async () => {
    setSaving(true); setFormError(null);
    try {
      if (modal === 'add') await createBankBranch(form);
      else await updateBankBranch(form.branch_id, form);
      close(); refetch();
    } catch (e) { setFormError(e.message || 'Save failed'); }
    finally { setSaving(false); }
  };

  if (loading) return <Spinner />;
  if (error)   return <ErrorBox message={error} onRetry={refetch} />;

  return (
    <>
      <PageHeader title="Branches" subtitle={`${data.length} records`}>
        <Btn onClick={openAdd}>+ Add Branch</Btn>
      </PageHeader>
      <div className="relative mb-4">
        <Search size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
        <input type="text" value={search} onChange={e => setSearch(e.target.value)} placeholder="Search by name, IFSC, city, state, phone..." className="w-full pl-10 pr-4 py-2.5 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500" />
      </div>
      <Card><DataTable columns={columns(openEdit)} rows={filtered} /></Card>

      <Modal open={!!modal} onClose={close} title={modal === 'add' ? 'Add Branch' : 'Edit Branch'}>
        <div className="grid grid-cols-2 gap-3">
          <FormField label="Branch Name"><Input value={form.branch_name} onChange={e => set('branch_name', e.target.value)} /></FormField>
          <FormField label="IFSC Code"><Input value={form.ifsc_code} onChange={e => set('ifsc_code', e.target.value)} disabled={modal !== 'add'} /></FormField>
          <FormField label="Address" className="col-span-2"><Input value={form.address} onChange={e => set('address', e.target.value)} disabled={modal !== 'add'} /></FormField>
          <FormField label="City"><Input value={form.city} onChange={e => set('city', e.target.value)} disabled={modal !== 'add'} /></FormField>
          <FormField label="State"><Input value={form.state} onChange={e => set('state', e.target.value)} disabled={modal !== 'add'} /></FormField>
          <FormField label="Pincode"><Input value={form.pincode} onChange={e => set('pincode', e.target.value)} disabled={modal !== 'add'} /></FormField>
          <FormField label="Phone"><Input value={form.phone} onChange={e => set('phone', e.target.value)} /></FormField>
          <FormField label="Email"><Input type="email" value={form.email} onChange={e => set('email', e.target.value)} /></FormField>
          {modal === 'add' && (
            <FormField label="Established Date"><Input type="date" value={form.established_date} onChange={e => set('established_date', e.target.value)} /></FormField>
          )}
          {modal !== 'add' && (
            <FormField label="Status">
              <Select value={form.status} onChange={e => set('status', e.target.value)}>
                <option value="active">active</option><option value="closed">closed</option>
              </Select>
            </FormField>
          )}
        </div>
        {formError && <div className="mt-3 p-3 bg-red-50 text-red-700 rounded-lg text-sm">{formError}</div>}
        <div className="flex justify-end gap-2 mt-4">
          <Btn variant="secondary" onClick={close}>Cancel</Btn>
          <Btn onClick={save} disabled={saving}>{saving ? 'Saving...' : 'Save'}</Btn>
        </div>
      </Modal>
    </>
  );
}
