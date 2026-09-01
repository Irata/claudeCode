## Custom Form Fields — Configured Vocabulary and Single-Lookup Patterns

### Purpose

Two field shapes that most data-layer components eventually need, and the traps in each.
Both were built for `com_entitydata` 0.3.0; the code below is generalised from
`AddresstypeField` and `EntitylookupField` in that component.

**Pattern A — a vocabulary the administrator controls.** A free-text column holding a
small set of legal values, with no lookup table behind it (`type`, `category`, `status`).
The lazy version populates the dropdown from the column itself:

```xml
<field name="type" type="sql" query="SELECT type FROM #__{table} GROUP BY type" ... />
```

That makes the vocabulary **self-defining**. The list can only ever offer what somebody
has already typed, so the first use of any new value has to be entered blind, a typo
becomes a permanent member of the vocabulary, and through a `<select>` there is no way to
add a value at all.

**Pattern B — one lookup, several stored columns.** A table that denormalises a
relationship across more than one column — say `entity_uuid` and `entity_id` — with an
edit form offering **a separate dropdown for each**. The record then has to be chosen
twice, and nothing stops the two choices naming different records. That is a data
integrity defect wearing a usability defect's clothes.

---

### Before anything else — four core facts that decide the design

These are the ones that cost an afternoon if you meet them by debugging.

**1. The field type becomes a class name via `Normalise::toSpaceSeparated()`.**
`FormHelper::loadClass()` space-separates the type, `ucwords()` it, and joins with `\`.
Underscores therefore become **namespace separators**:

| `type="…"` | class it looks for |
|---|---|
| `addresstype` | `…\Field\AddresstypeField` |
| `address_type` | `…\Field\Address\TypeField` ← almost certainly not what you meant |

**Use a single lower-case word.** Point at the namespace with `addfieldprefix` on the
field itself, or `FormHelper::addFieldPrefix()` at runtime:

```xml
<field name="type" type="addresstype"
       addfieldprefix="Vendor\Component\Example\Administrator\Field" />
```

**2. `ListField::getInput()` renders `$this->layout` and injects the options for you.**

```php
$data            = $this->collectLayoutData();
$data['options'] = (array) $this->getOptions();

return $this->getRenderer($this->layout)->render($data);
```

So a `layout="…"` attribute changes how *any* list-derived field renders without touching
where its options come from. `type="sql"` plus `layout="joomla.form.field.combo"` is a
database-driven combo box with no PHP at all.

**3. `header` becomes a real option, not a placeholder.** `ListField::getOptions()`
prepends `HTMLHelper::_('select.option', '', Text::_($header))`. In a `<select>` that is
the harmless "- Select -" row. In the **combo** layout, which builds its suggestion list
from option *text*, your header string is offered as a selectable value. Drop `header`
from anything rendered as a combo.

**4. `filter="unset"` does NOT remove the key — it sets it to `null`.** `UnsetFilter`
returns `null`, and `Form::filter()` writes that null into the output array. A read-only
display field marked `unset` therefore reaches the model as `null`, and binding null to a
`NOT NULL` column is an error, not a no-op. **The model must set such values
unconditionally** — never "only if missing".

---

### Pattern A — a vocabulary the administrator controls

Move the vocabulary into the component's Options and read it from a field class.

#### The Options side

```xml
<fieldset name="{things}" label="COM_{EXAMPLE}_FIELDSET_CONFIG_{THINGS}_LABEL">
    <field name="{thing}_types" type="subform" multiple="true"
           label="COM_{EXAMPLE}_FIELD_{THING}_TYPES_LABEL"
           layout="joomla.form.field.subform.repeatable-table">
        <form name="{thing}_types_row" repeat="true">
            <field name="type" type="text" required="true" filter="string"
                   label="COM_{EXAMPLE}_FIELD_{THING}_TYPE_LABEL" />
        </form>
    </field>
</fieldset>
```

A repeatable subform stores an **object of objects**, keyed `{thing}_types0`,
`{thing}_types1`, … — cast at both levels rather than indexing into them.

#### The field

```php
final class {Thing}typeField extends ListField
{
    protected $type = '{Thing}type';

    protected function getOptions(): array
    {
        // parent::getOptions() honours <option> children and the `header` attribute.
        $options = parent::getOptions();
        $seen    = [];

        foreach ($options as $option) {
            $seen[(string) $option->value] = true;
        }

        $values   = $this->configuredTypes() ?: $this->typesInUse();
        $values[] = trim((string) $this->value);          // source 3, always

        foreach ($values as $value) {
            if ($value === '' || isset($seen[$value])) {
                continue;
            }

            $seen[$value] = true;
            $options[]    = HTMLHelper::_('select.option', $value, $value);
        }

        return $options;
    }
}
```

**Three sources, and their order is the whole design:**

| # | Source | Why |
|---|---|---|
| 1 | Types configured in Options | Whenever any exist they are the answer, in administrator order |
| 2 | Distinct values already in the column, **only if none are configured** | A site that has never opened Options keeps exactly the list it had before. Nothing to migrate, and no empty dropdown on day one |
| 3 | The record's own stored value, **always** | Without it, withdrawing a type in Options blanks it on every record still using it at the next save — silent data loss during an edit that was about something else |

#### Two traps in this pattern

**`ComponentHelper::getParams()` throws outside a web request.** It needs a running
application, so a console command or a test harness gets `Failed to start application`.
Wrap it and fall through to source 2:

```php
try {
    $rows = ComponentHelper::getParams('com_{example}')->get('{thing}_types');
} catch (\Throwable) {
    return [];
}
```

Split the *parsing* of the subform value into its own method. The lookup is one line; the
shape handling is where the edge cases live, and separated it can be tested without
booting an application.

**Do not "fix" the original problem with a combo box.**
`layout="joomla.form.field.combo"` renders an Awesomplete text input and does accept new
values — but Awesomplete's `minChars` is **2**, so nothing is suggested until two
characters are typed. A controlled vocabulary becomes unbrowsable: the legal values cannot
be discovered, only guessed at. A combo is right for genuinely open text with hints, and
wrong for a closed list.

---

### Pattern B — one lookup, several stored columns

**The rule: the lookup is not a column.** It is an unstored control that the model
resolves into every column the relationship is denormalised across.

#### The form

```xml
<field name="{thing}_lookup" type="{thing}lookup" required="true"
       addfieldprefix="Vendor\Component\Example\Administrator\Field"
       label="COM_{EXAMPLE}_FIELD_{THING}_LOOKUP_LABEL" />

<field name="{thing}_uuid" type="text" label="…"
       class="readonly" readonly="true" filter="unset" />

<field name="{thing}_id" type="text" label="…"
       class="readonly" readonly="true" filter="unset" />
```

Order matters for comprehension: keep the other *inputs* beside the lookup and put the
derived read-only boxes **below** them. They are output, not input.

#### The model

```php
public function save($data)
{
    if (isset($data['{thing}_lookup'])) {
        $uuid = trim((string) $data['{thing}_lookup']);

        $data['{thing}_uuid'] = $uuid;
        $data['{thing}_id']   = $this->idForUuid($uuid);   // derived, never trusted

        unset($data['{thing}_lookup']);
    }

    return parent::save($data);
}

protected function loadFormData()
{
    // …
    // The lookup is not a column, so getItem() never returns it. Without this the
    // select opens on the header even for a record that plainly has a value.
    if (\is_object($data) && !empty($data->{thing}_uuid)) {
        $data->{thing}_lookup = $data->{thing}_uuid;
    }
}
```

**Derive, never trust.** `filter="unset"` plus server-side derivation is what makes the
columns unable to disagree — a tampered POST cannot set them independently of the choice.
Remember fact 4 above: `unset` yields `null`, not an absent key, so the model has to write
these values on every save.

**Key the lookup on the canonical column.** Use whichever column carries the unique key
and the cross-extension identity — usually the uuid — and derive the convenience copy from
it. Return `null`, not `0`, when a lookup misses: a `0` in a nullable foreign-key column
reads as a real record that does not exist.

#### Keeping the read-only boxes live

Optional, and it must stay optional. Register an inline script from `getInput()` that
mirrors the selection into the read-only inputs:

```php
$base = preg_replace('/' . preg_quote($this->fieldname, '/') . '$/', '', $this->id);
```

`$this->id` is `jform_{thing}_lookup`, so stripping the field name leaves the control
prefix, and the siblings are then found inside a subform or field group too. Guard every
`getElementById` — the same field will serve forms that store only one of the columns.

**The script is cosmetic.** With JavaScript off the boxes lag until the save and the
stored values are still correct, because the model derives them. If the script is
load-bearing, the pattern has been implemented wrongly.

#### Reuse across forms

One lookup class serves every form that picks the same record, even where they store
different subsets of its identity — a form with no `{thing}_id` column simply skips that
element. Say so in the form comment, or the difference reads as an oversight later.

---

### Traps worth naming

**`validate="options"` on a `type="text"` field makes the screen unsaveable.**
`OptionsRule::test()` builds its permitted list from the field's own `<option>` children.
A text field has none, so the list is empty and every non-blank value is rejected with
`Invalid field: <label>`. It returns `true` early only when the value is blank and the
field is not required — so an empty value passes and a real one does not. This is a
frequent copy-paste artefact in `config.xml`. If a setting is not implemented yet, delete
the field and keep the fieldset, rather than shipping a control that cannot be saved.

**XML comments cannot contain `--`.** Form and manifest XML is parsed strictly, and a
double hyphen inside `<!-- … -->` is a hard parse error. These are heavily commented files
and the em-dash habit bites often.

**A component's own language file can be shadowed.**
`ComponentDispatcher::loadLanguage()` is
`load($option, JPATH_BASE) || load($option, JPATH_BASE . '/components/' . $option)`, and
`Language::load()` returns on the **first** filename that loads. A stale
`administrator/language/en-GB/com_{example}.ini` left behind by a Joomla 3-era install
therefore wins outright, and every key added to the component's own file since then is
invisible. The symptom is distinctive: newly added constants render raw while older ones
resolve normally.

---

### Checklist

- [ ] Field type is a single lower-case word; class is `{Type}Field` under `src/Field/`
- [ ] `addfieldprefix` on the field, or the prefix registered at runtime
- [ ] `final class`, `protected $type`, extends `ListField` for anything option-based
- [ ] Vocabulary fields: configured source, in-use fallback, current value always present
- [ ] `ComponentHelper::getParams()` wrapped against "Failed to start application"
- [ ] Subform parsing split out so it can be tested without an application
- [ ] Lookup fields: the lookup is not a column; the model derives every stored value
- [ ] Read-only companions carry `filter="unset"` **and** the model sets them unconditionally
- [ ] `loadFormData()` primes the lookup, or edit forms open on the header
- [ ] Any inline script is cosmetic, and every element lookup is guarded
- [ ] No `header` on a field rendered with the combo layout
- [ ] No `validate="options"` on anything without `<option>` children
