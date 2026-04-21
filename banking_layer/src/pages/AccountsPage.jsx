import { useState, useMemo } from 'react';
import { useApi } from '../hooks';
import { getAccounts, createAccount, updateAccount, getCustomers, getBranches, getEmployees } from '../api';
import { PageHeader, Card, DataTable, Badge, Spinner, ErrorBox, Modal, FormField, Input, Select, Btn } from '../components/UI';
import { Search } from 'lucide-react';

const statusColor = { active: 'green', frozen: 'amber', dormant: 'amber', closed: 'red' };

const columns = (onEdit) => [
  { key: 'account_id',      label: 'ID' },
  { key: 'account_number',  label: 'Account #' },
  { key: 'customer_name',   label: 'Customer' },
  { key: 'account_type',    label: 'Type', render: (r) => <Badge variant="blue">{r.account_type}</Badge> },
  { key: 'current_balance', label: 'Balance', render: (r) => `₹${Number(r.current_balance).toLocaleString('en-IN')}` },
  { key: 'interest_rate',   label: 'Rate %' },
  { key: 'opened_date',     label: 'Opened', render: (r) => r.opened_date?.slice(0, 10) },
  { key: 'status', label: 'Status', render: (r) => <Badge variant={statusColor[r.status]}>{r.status}</Badge> },
  { key: '_edit', label: '', render: (r) => <Btn variant="secondary" onClick={() => onEdit(r)}>Edit</Btn> },
];

const empty = { customer_id: '', branch_id: '', opened_by: '', account_number: '', account_type: 'savings', min_balance: '0', interest_rate: '3.5' };

export default function AccountsPage() {
  const { data, loading, error, refetch } = useApi(getAccounts);
  const customers = useApi(getCustomers);
  const branches = useApi(getBranches);
  const employees = useApi(getEmployees);
  const [modal, setModal] = useState(null);
  const [form, setForm] = useState(empty);
  const [saving, setSaving] = useState(false);
  const [formError, setFormError] = useState(null);
  const [search, setSearch] = useState('');

  const filtered = useMemo(() => {
    if (!data || !search.trim()) return data || [];
    const q = search.toLowerCase();
    return data.filter(r => [r.account_number, r.customer_name, r.account_type, r.status].some(v => v && String(v).toLowerCase().includes(q)));
  }, [data, search]);

  const openAdd = () => { setForm(empty); setFormError(null); setModal('add'); };
  const openEdit = (r) => { setForm({ ...r }); setFormError(null); setModal(r); };
  const close = () => { setModal(null); setFormError(null); };
  const set = (k, v) => setForm(f => ({ ...f, [k]: v }));

  const save = async () => {
    setSaving(true); setFormError(null);
    try {
      if (modal === 'add') await createAccount(form);
      else await updateAccount(form.account_id, form);
      close(); refetch();
    } catch (e) { setFormError(e.message || 'Save failed'); }
    finally { setSaving(false); }
  };

  if (loading) return <Spinner />;
  if (error) return <ErrorBox message={error} onRetry={refetch} />;

  return (
    <>
      <PageHeader title="Accounts" subtitle={`${data.length} records`}>
        <Btn onClick={openAdd}>+ Add Account</Btn>
      </PageHeader>
      <div className="relative mb-4">
        <Search size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
        <input type="text" value={search} onChange={e => setSearch(e.target.value)} placeholder="Search by account number, customer, type, status..." className="w-full pl-10 pr-4 py-2.5 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500" />
      </div>
      <Card><DataTable columns={columns(openEdit)} rows={filtered} /></Card>

      <Modal open={!!modal} onClose={close} title={modal === 'add' ? 'Add Account' : 'Edit Account'}>
        <div className="grid grid-cols-2 gap-3">
          {modal === 'add' && (
            <>
              <FormField label="Customer">
                <Select value={form.customer_id} onChange={e => set('customer_id', e.target.value)}>
                  <option value="">Select</option>
                  {(customers.data || []).map(c => <option key={c.customer_id} value={c.customer_id}>{c.full_name}</option>)}
                </Select>
              </FormField>
              <FormField label="Branch">
                <Select value={form.branch_id} onChange={e => set('branch_id', e.target.value)}>
                  <option value="">Select</option>
                  {(branches.data || []).map(b => <option key={b.branch_id} value={b.branch_id}>{b.branch_name}</option>)}
                </Select>
              </FormField>
              <FormField label="Opened By">
                <Select value={form.opened_by} onChange={e => set('opened_by', e.target.value)}>
                  <option value="">Select</option>
                  {(employees.data || []).map(e => <option key={e.emp_id} value={e.emp_id}>{e.full_name}</option>)}
                </Select>
              </FormField>
              <FormField label="Account Number"><Input value={form.account_number} onChange={e => set('account_number', e.target.value)} placeholder="e.g. 1001000007" /></FormField>
              <FormField label="Account Type">
                <Select value={form.account_type} onChange={e => set('account_type', e.target.value)}>
                  {['savings','current','salary','NRE','NRO'].map(v => <option key={v} value={v}>{v}</option>)}
                </Select>
              </FormField>
            </>
          )}
          <FormField label="Interest Rate %"><Input type="number" step="0.01" value={form.interest_rate} onChange={e => set('interest_rate', e.target.value)} /></FormField>
          <FormField label="Min Balance"><Input type="number" value={form.min_balance} onChange={e => set('min_balance', e.target.value)} /></FormField>
          {modal !== 'add' && (
            <FormField label="Status">
              <Select value={form.status} onChange={e => set('status', e.target.value)}>
                {['active','frozen','dormant','closed'].map(v => <option key={v} value={v}>{v}</option>)}
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
