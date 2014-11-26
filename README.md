yams-cookbook
=============

TODO: www.thesilenceoftheyams.com

Attributes
----------

<table>
  <tr>
    <th>Key</th>
    <th>Type</th>
    <th>Description</th>
    <th>Default</th>
  </tr>
  <tr>
    <td><tt>['yams']['bacon']</tt></td>
    <td>Boolean</td>
    <td>whether to include bacon</td>
    <td><tt>true</tt></td>
  </tr>
</table>

Usage
-----

### yams::db

Include `yams::db` in your node's `run_list`:

```json
{
  "run_list": [
    "recipe[yams::db]"
  ]
}
```

### yams::app

The application server recipe requires exactly one database node, or the recipe will fail with an error.

Include `yams::app` in your node's `run_list`:

```json
{
  "run_list": [
    "recipe[yams::app]"
  ]
}
```

License and Authors
-------------------

Author:: Kevin J. Dickerson (kevin.dickerson@loom.technology)

TODO
----

-	Automate theme.
-	Add tests.
-	Encrypt data bags.
-	Define, and then refactor attributes and data bag structure.
