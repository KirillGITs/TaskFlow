from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('search', '0001_initial'),
    ]

    operations = [
        migrations.AlterField(
            model_name='foundarticle',
            name='url',
            field=models.URLField(max_length=1000),
        ),
    ]
