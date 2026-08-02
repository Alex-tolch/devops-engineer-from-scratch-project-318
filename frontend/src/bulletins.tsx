import {
  Create,
  Datagrid,
  Edit,
  EditButton,
  ImageField,
  ImageInput,
  List,
  NumberField,
  NumberInput,
  required,
  SelectField,
  SelectInput,
  Show,
  ShowButton,
  SimpleForm,
  SimpleShowLayout,
  TextField,
  TextInput,
} from "react-admin";

const stateChoices = [
  { id: "DRAFT", name: "Draft" },
  { id: "PUBLISHED", name: "Published" },
];

const BulletinForm = () => (
  <SimpleForm>
    <TextInput source="title" fullWidth validate={[required()]} />
    <TextInput
      source="description"
      multiline
      minRows={3}
      fullWidth
      validate={[required()]}
    />
    <SelectInput
      source="state"
      choices={stateChoices}
      validate={[required()]}
    />
    <TextInput source="contact" fullWidth validate={[required()]} />
    <NumberInput
      source="price"
      label="Price"
      min={0}
      step={0.01}
      validate={[required()]}
    />
    <ImageField source="imageUrl" label="Current image" />
    <ImageInput source="image" label="Upload image" accept="image/*">
      <ImageField source="src" title="title" />
    </ImageInput>
  </SimpleForm>
);

export const BulletinList = () => (
  <List perPage={9} sort={{ field: "createdAt", order: "DESC" }}>
    <Datagrid rowClick="show">
      <TextField source="id" />
      <TextField source="title" />
      <SelectField source="state" choices={stateChoices} />
      <TextField source="contact" />
      <NumberField
        source="price"
        label="Price"
        options={{ style: "currency", currency: "USD" }}
      />
      <ImageField source="imageUrl" label="Image" />
      <ShowButton />
      <EditButton />
    </Datagrid>
  </List>
);

export const BulletinShow = () => (
  <Show>
    <SimpleShowLayout>
      <TextField source="id" />
      <TextField source="title" />
      <TextField source="description" />
      <SelectField source="state" choices={stateChoices} />
      <TextField source="contact" />
      <NumberField
        source="price"
        label="Price"
        options={{ style: "currency", currency: "USD" }}
      />
      <ImageField source="imageUrl" label="Image" />
    </SimpleShowLayout>
  </Show>
);

export const BulletinEdit = () => (
  <Edit>
    <BulletinForm />
  </Edit>
);

export const BulletinCreate = () => (
  <Create>
    <BulletinForm />
  </Create>
);
